package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"breach3v3/server/modules/config"
	gamepb "breach3v3/server/modules/protobuf"
	"breach3v3/server/modules/state"
	"breach3v3/server/modules/systems"

	"github.com/golang/protobuf/proto"
	"github.com/heroiclabs/nakama-common/runtime"
)

const (
	OpCodeMove                 int64 = 1
	OpCodeGameState            int64 = 2
	OpCodeCharacterSelect      int64 = 3
	OpCodeCharacterSelectState int64 = 4
	OpCodeRoomReady            int64 = 5
	OpCodeRoomState            int64 = 6
	OpCodeRoomStartMatch       int64 = 7

	RpcCreateMatch = "create_breach_match"
)

type BreachMatch struct{}

func InitModule(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, initializer runtime.Initializer) error {
	if err := initializer.RegisterMatch(config.MATCH_MODULE_NAME, newMatch); err != nil {
		logger.Error("failed to register match handler: %v", err)
		return err
	}
	if err := initializer.RegisterRpc(RpcCreateMatch, rpcCreateMatch); err != nil {
		logger.Error("failed to register create match rpc: %v", err)
		return err
	}
	if err := initializer.RegisterMatchmakerMatched(matchmakerMatched); err != nil {
		logger.Error("failed to register matchmaker matched hook: %v", err)
		return err
	}
	logger.Info("registered authoritative match handler: %s", config.MATCH_MODULE_NAME)
	return nil
}

func rpcCreateMatch(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, payload string) (string, error) {
	matchID, err := nk.MatchCreate(ctx, config.MATCH_MODULE_NAME, map[string]interface{}{})
	if err != nil {
		logger.Error("failed to create authoritative match: %v", err)
		return "", err
	}
	logger.Info("created authoritative match id=%s module=%s", matchID, config.MATCH_MODULE_NAME)

	response, err := json.Marshal(map[string]string{"match_id": matchID})
	if err != nil {
		return "", err
	}
	return string(response), nil
}

func matchmakerMatched(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, entries []runtime.MatchmakerEntry) (string, error) {
	partyGroups := make(map[string][]string)
	for _, entry := range entries {
		partyID := entry.GetPartyId()
		userID := entry.GetPresence().GetUserId()
		partyGroups[partyID] = append(partyGroups[partyID], userID)
	}
	params := map[string]interface{}{
		"party_groups": partyGroups,
	}
	matchID, err := nk.MatchCreate(ctx, config.MATCH_MODULE_NAME, params)
	if err != nil {
		logger.Error("failed to create authoritative match for matchmaker entries=%d err=%v", len(entries), err)
		return "", err
	}
	logger.Info("matchmaker created authoritative match id=%s entries=%d parties=%d", matchID, len(entries), len(partyGroups))
	return matchID, nil
}

func newMatch(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule) (runtime.Match, error) {
	return &BreachMatch{}, nil
}

func (m *BreachMatch) MatchInit(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, params map[string]interface{}) (interface{}, int, string) {
	cfg := config.Active()
	matchState := state.NewMatchState()
	if raw, ok := params["party_groups"]; ok {
		if groups, ok := raw.(map[string]interface{}); ok {
			for partyID, usersRaw := range groups {
				if users, ok := usersRaw.([]interface{}); ok {
					userIDs := make([]string, 0, len(users))
					for _, u := range users {
						if uid, ok := u.(string); ok {
							userIDs = append(userIDs, uid)
							matchState.UserParty[uid] = partyID
						}
					}
					matchState.PartySize[partyID] = len(userIDs)
				}
			}
			logger.Info("breach match initialized config_version=%d tick_rate=%d parties=%d", cfg.Version, cfg.Match.TickRate, len(matchState.PartySize))
		}
	} else {
		logger.Info("breach match initialized config_version=%d tick_rate=%d", cfg.Version, cfg.Match.TickRate)
	}
	return matchState, cfg.Match.TickRate, "mode=bomb_defusal"
}

func (m *BreachMatch) MatchJoinAttempt(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, matchState interface{}, presence runtime.Presence, metadata map[string]string) (interface{}, bool, string) {
	current, ok := matchState.(*state.MatchState)
	if !ok {
		logger.Error("invalid match state type during join attempt")
		return matchState, false, "internal match state error"
	}
	cfg := config.Active()
	if _, exists := current.Players[presence.GetUserId()]; !exists && len(current.Players) >= cfg.Match.MaxPlayers {
		return current, false, "match is full"
	}
	return current, true, ""
}

func (m *BreachMatch) MatchJoin(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, matchState interface{}, presences []runtime.Presence) interface{} {
	current := matchState.(*state.MatchState)
	cfg := config.Active()
	character := cfg.DefaultCharacter()
	for _, presence := range presences {
		player, exists := current.Players[presence.GetUserId()]
		if !exists {
			faction := current.AssignFaction(presence.GetUserId())
			spawn := spawnPoint(faction, len(current.Players))
			player = &state.Player{
				UserID:      presence.GetUserId(),
				SessionID:   presence.GetSessionId(),
				Username:    presence.GetUsername(),
				DisplayName: presence.GetUsername(),
				CharacterID: character.ID,
				Faction:     faction,
				Position:    spawn,
				LastValid:   spawn,
				Health:      character.BaseHealth,
			}
			current.Players[player.UserID] = player
		}
		player.SessionID = presence.GetSessionId()
		player.Username = presence.GetUsername()
		player.DisplayName = presence.GetUsername()
		player.Presence = presence
		player.Connected = true
		logger.Info("player joined user_id=%s session_id=%s faction=%d", player.UserID, player.SessionID, player.Faction)
	}
	_ = broadcastRoomState(logger, dispatcher, current)
	return current
}

func (m *BreachMatch) MatchLeave(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, matchState interface{}, presences []runtime.Presence) interface{} {
	current := matchState.(*state.MatchState)
	for _, presence := range presences {
		if player, ok := current.Players[presence.GetUserId()]; ok {
			player.Connected = false
			logger.Info("player left user_id=%s session_id=%s", presence.GetUserId(), presence.GetSessionId())
		}
	}
	_ = broadcastRoomState(logger, dispatcher, current)
	return current
}

func (m *BreachMatch) MatchLoop(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, matchState interface{}, messages []runtime.MatchData) interface{} {
	current := matchState.(*state.MatchState)
	cfg := config.Active()
	if current.ConnectedCount() == 0 && tick > int64(cfg.Match.TickRate*5) {
		logger.Info("terminating empty match tick=%d", tick)
		return nil
	}
	tickInterval := 1.0 / float64(current.TickRate)
	for _, message := range messages {
		switch message.GetOpCode() {
		case OpCodeMove:
			processMove(logger, dispatcher, current, message, tickInterval)
		case OpCodeCharacterSelect:
			processCharacterSelect(logger, dispatcher, current, message)
		case OpCodeRoomReady:
			processRoomReady(logger, dispatcher, current, message)
		case OpCodeRoomStartMatch:
			processRoomStartMatch(logger, dispatcher, nk, current, message)
		default:
			logger.Warn("ignored unknown match op_code=%d user_id=%s", message.GetOpCode(), message.GetUserId())
		}
	}

	now := time.Now().UTC()
	systems.UpdateRound(current, now)
	if err := broadcastGameState(logger, dispatcher, current, tick, now); err != nil {
		logger.Error("failed to broadcast game state: %v", err)
	}
	logger.Debug("tick=%d players=%d phase=%d", tick, current.ConnectedCount(), current.Phase)
	return current
}

func processCharacterSelect(logger runtime.Logger, dispatcher runtime.MatchDispatcher, current *state.MatchState, message runtime.MatchData) {
	player, ok := current.Players[message.GetUserId()]
	if !ok || !player.Connected {
		logger.Warn("character select rejected for unknown/disconnected user_id=%s", message.GetUserId())
		return
	}

	selection := &gamepb.CharacterSelect{}
	if err := proto.Unmarshal(message.GetData(), selection); err != nil {
		logger.Warn("character select rejected invalid protobuf user_id=%s err=%v", message.GetUserId(), err)
		return
	}
	if selection.Version != gamepb.PROTOCOL_VERSION {
		logger.Warn("character select rejected bad protocol user_id=%s version=%d", message.GetUserId(), selection.Version)
		return
	}

	cfg := config.Active()
	character := cfg.Character(selection.CharacterId)
	player.CharacterID = character.ID
	player.Health = character.BaseHealth
	player.CharacterLocked = true
	logger.Info("character locked user_id=%s character_id=%s", player.UserID, player.CharacterID)

	if err := broadcastCharacterSelectState(logger, dispatcher, current); err != nil {
		logger.Error("failed to broadcast character select state: %v", err)
	}
}

func (m *BreachMatch) MatchTerminate(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, matchState interface{}, graceSeconds int) interface{} {
	logger.Info("match terminating tick=%d grace_seconds=%d", tick, graceSeconds)
	return matchState
}

func (m *BreachMatch) MatchSignal(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, matchState interface{}, data string) (interface{}, string) {
	return matchState, "ok"
}

func processMove(logger runtime.Logger, dispatcher runtime.MatchDispatcher, current *state.MatchState, message runtime.MatchData, tickInterval float64) {
	player, ok := current.Players[message.GetUserId()]
	if !ok || !player.Connected {
		logger.Warn("move rejected for unknown/disconnected user_id=%s", message.GetUserId())
		return
	}

	move := &gamepb.MoveCommand{}
	if err := proto.Unmarshal(message.GetData(), move); err != nil {
		logger.Warn("move rejected invalid protobuf user_id=%s err=%v", message.GetUserId(), err)
		return
	}
	if move.Version != gamepb.PROTOCOL_VERSION || move.Position == nil {
		logger.Warn("move rejected bad protocol user_id=%s version=%d", message.GetUserId(), move.Version)
		return
	}

	next := state.Vec2{X: float64(move.Position.X), Y: float64(move.Position.Y)}
	result := systems.ValidateMove(player, next, tickInterval)
	if !result.Accepted {
		logger.Warn("cheat_attempt user_id=%s session_id=%s type=invalid_move reason=%s last=(%.2f,%.2f) requested=(%.2f,%.2f)",
			player.UserID, player.SessionID, result.Reason, player.LastValid.X, player.LastValid.Y, next.X, next.Y)
		player.Position = player.LastValid
		if result.Reason == "speed_limit" {
			if err := dispatcher.MatchKick([]runtime.Presence{message}); err != nil {
				logger.Error("failed to kick invalid mover user_id=%s err=%v", player.UserID, err)
			}
		}
		return
	}

	player.Position = next
	player.LastValid = next
}

func broadcastGameState(logger runtime.Logger, dispatcher runtime.MatchDispatcher, current *state.MatchState, tick int64, now time.Time) error {
	snapshot := &gamepb.GameState{
		Version:            gamepb.PROTOCOL_VERSION,
		Tick:               uint64(tick),
		RoundState:         int32(current.Phase),
		RoundTimeRemaining: systems.RoundTimeRemaining(current, now),
		Players:            make([]*gamepb.PlayerState, 0, len(current.Players)),
	}
	for _, player := range current.SortedPlayers() {
		snapshot.Players = append(snapshot.Players, &gamepb.PlayerState{
			UserId:      player.UserID,
			DisplayName: player.DisplayName,
			Faction:     int32(player.Faction),
			Position: &gamepb.Vector2{
				X: float32(player.Position.X),
				Y: float32(player.Position.Y),
			},
			Health:    int32(player.Health),
			Connected: player.Connected,
		})
	}

	data, err := proto.Marshal(snapshot)
	if err != nil {
		return fmt.Errorf("marshal game state: %w", err)
	}
	return dispatcher.BroadcastMessage(OpCodeGameState, data, current.ActivePresences(), nil, true)
}

func broadcastCharacterSelectState(logger runtime.Logger, dispatcher runtime.MatchDispatcher, current *state.MatchState) error {
	players := current.SortedPlayers()
	snapshot := &gamepb.CharacterSelectState{
		Version: gamepb.PROTOCOL_VERSION,
		Players: make([]*gamepb.CharacterSelectPlayer, 0, len(players)),
	}
	snapshot.AllLocked = false
	connectedCount := 0
	for _, player := range players {
		if !player.Connected {
			continue
		}
		connectedCount++
		if !player.CharacterLocked {
			snapshot.AllLocked = false
		} else if connectedCount == 1 {
			snapshot.AllLocked = true
		}
		snapshot.Players = append(snapshot.Players, &gamepb.CharacterSelectPlayer{
			UserId:      player.UserID,
			DisplayName: player.DisplayName,
			CharacterId: player.CharacterID,
			Locked:      player.CharacterLocked,
		})
	}

	data, err := proto.Marshal(snapshot)
	if err != nil {
		return fmt.Errorf("marshal character select state: %w", err)
	}
	return dispatcher.BroadcastMessage(OpCodeCharacterSelectState, data, current.ActivePresences(), nil, true)
}

func spawnPoint(faction state.Faction, index int) state.Vec2 {
	cfg := config.Active()
	if point, ok := configuredSpawnPoint(cfg, faction, index); ok {
		return point
	}
	offset := float64(index%3) * 42
	if faction == state.FACTION_ATTACKERS {
		return state.Vec2{X: 120 + offset, Y: 180 + offset}
	}
	return state.Vec2{X: cfg.Map.Width - 120 - offset, Y: cfg.Map.Height - 180 - offset}
}

func configuredSpawnPoint(cfg *config.GameConfig, faction state.Faction, index int) (state.Vec2, bool) {
	key := "defenders"
	if faction == state.FACTION_ATTACKERS {
		key = "attackers"
	}
	points := cfg.Map.SpawnPoints[key]
	if len(points) == 0 {
		return state.Vec2{}, false
	}
	point := points[index%len(points)]
	return state.Vec2{X: point.X, Y: point.Y}, true
}

func processRoomReady(logger runtime.Logger, dispatcher runtime.MatchDispatcher, current *state.MatchState, message runtime.MatchData) {
	player, ok := current.Players[message.GetUserId()]
	if !ok || !player.Connected {
		return
	}
	ready := &gamepb.RoomReady{}
	if err := proto.Unmarshal(message.GetData(), ready); err != nil {
		return
	}
	if ready.Version != gamepb.PROTOCOL_VERSION {
		return
	}
	player.Ready = ready.Ready
	logger.Info("player ready changed user_id=%s ready=%v", player.UserID, player.Ready)
	if err := broadcastRoomState(logger, dispatcher, current); err != nil {
		logger.Error("failed to broadcast room state after ready: %v", err)
	}
}

func processRoomStartMatch(logger runtime.Logger, dispatcher runtime.MatchDispatcher, nk runtime.NakamaModule, current *state.MatchState, message runtime.MatchData) {
	player, ok := current.Players[message.GetUserId()]
	if !ok || !player.Connected {
		return
	}
	sorted := current.SortedPlayers()
	if len(sorted) == 0 || sorted[0].UserID != player.UserID {
		logger.Warn("room start rejected: not host user_id=%s", player.UserID)
		return
	}
	for _, p := range current.Players {
		if p.Connected && !p.Ready {
			logger.Warn("room start rejected: not all ready user_id=%s", player.UserID)
			return
		}
	}
	gameMatchID, err := nk.MatchCreate(context.Background(), config.MATCH_MODULE_NAME, map[string]interface{}{})
	if err != nil {
		logger.Error("failed to create game match from room: %v", err)
		return
	}
	logger.Info("room host started game room=%s game_match=%s", message.GetUserId(), gameMatchID)
	current.GameMatchID = gameMatchID
	if err := broadcastRoomState(logger, dispatcher, current); err != nil {
		logger.Error("failed to broadcast room state with game match: %v", err)
	}
}

func broadcastRoomState(logger runtime.Logger, dispatcher runtime.MatchDispatcher, current *state.MatchState) error {
	players := current.SortedPlayers()
	snapshot := &gamepb.RoomState{
		Version:     gamepb.PROTOCOL_VERSION,
		PlayerCount: int32(len(players)),
		Players:     make([]*gamepb.RoomPlayer, 0, len(players)),
		GameMatchId: current.GameMatchID,
	}
	for _, player := range players {
		snapshot.Players = append(snapshot.Players, &gamepb.RoomPlayer{
			UserId:      player.UserID,
			DisplayName: player.DisplayName,
			Ready:       player.Ready,
		})
	}
	data, err := proto.Marshal(snapshot)
	if err != nil {
		return fmt.Errorf("marshal room state: %w", err)
	}
	return dispatcher.BroadcastMessage(OpCodeRoomState, data, current.ActivePresences(), nil, true)
}
