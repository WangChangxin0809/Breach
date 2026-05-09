package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"time"

	"breach3v3/backend/modules/config"
	gamepb "breach3v3/backend/modules/protobuf"
	"breach3v3/backend/modules/state"
	"breach3v3/backend/modules/systems"

	"github.com/golang/protobuf/proto"
	"github.com/heroiclabs/nakama-common/runtime"
)

const (
	OpCodeMove      int64 = 1
	OpCodeGameState int64 = 2

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
	matchID, err := nk.MatchCreate(ctx, config.MATCH_MODULE_NAME, map[string]interface{}{})
	if err != nil {
		logger.Error("failed to create authoritative match for matchmaker entries=%d err=%v", len(entries), err)
		return "", err
	}
	logger.Info("matchmaker created authoritative match id=%s entries=%d", matchID, len(entries))
	return matchID, nil
}

func newMatch(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule) (runtime.Match, error) {
	return &BreachMatch{}, nil
}

func (m *BreachMatch) MatchInit(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, params map[string]interface{}) (interface{}, int, string) {
	logger.Info("breach match initialized tick_rate=%d", config.MATCH_TICK_RATE)
	return state.NewMatchState(), config.MATCH_TICK_RATE, "mode=bomb_defusal"
}

func (m *BreachMatch) MatchJoinAttempt(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, matchState interface{}, presence runtime.Presence, metadata map[string]string) (interface{}, bool, string) {
	current, ok := matchState.(*state.MatchState)
	if !ok {
		logger.Error("invalid match state type during join attempt")
		return matchState, false, "internal match state error"
	}
	if _, exists := current.Players[presence.GetUserId()]; !exists && len(current.Players) >= config.MATCH_MAX_PLAYERS {
		return current, false, "match is full"
	}
	return current, true, ""
}

func (m *BreachMatch) MatchJoin(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, matchState interface{}, presences []runtime.Presence) interface{} {
	current := matchState.(*state.MatchState)
	for _, presence := range presences {
		player, exists := current.Players[presence.GetUserId()]
		if !exists {
			faction := assignFaction(current)
			spawn := spawnPoint(faction, len(current.Players))
			player = &state.Player{
				UserID:      presence.GetUserId(),
				SessionID:   presence.GetSessionId(),
				Username:    presence.GetUsername(),
				DisplayName: presence.GetUsername(),
				Faction:     faction,
				Position:    spawn,
				LastValid:   spawn,
				Health:      config.PLAYER_BASE_HEALTH,
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
	return current
}

func (m *BreachMatch) MatchLoop(ctx context.Context, logger runtime.Logger, db *sql.DB, nk runtime.NakamaModule, dispatcher runtime.MatchDispatcher, tick int64, matchState interface{}, messages []runtime.MatchData) interface{} {
	current := matchState.(*state.MatchState)
	if current.ConnectedCount() == 0 && tick > int64(config.MATCH_TICK_RATE*5) {
		logger.Info("terminating empty match tick=%d", tick)
		return nil
	}
	tickInterval := 1.0 / float64(current.TickRate)
	for _, message := range messages {
		switch message.GetOpCode() {
		case OpCodeMove:
			processMove(logger, dispatcher, current, message, tickInterval)
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

func assignFaction(current *state.MatchState) state.Faction {
	attackers := 0
	defenders := 0
	for _, player := range current.Players {
		if player.Faction == state.FACTION_ATTACKERS {
			attackers++
		} else {
			defenders++
		}
	}
	if attackers <= defenders {
		return state.FACTION_ATTACKERS
	}
	return state.FACTION_DEFENDERS
}

func spawnPoint(faction state.Faction, index int) state.Vec2 {
	offset := float64(index%3) * 42
	if faction == state.FACTION_ATTACKERS {
		return state.Vec2{X: 120 + offset, Y: 180 + offset}
	}
	return state.Vec2{X: config.MAP_WIDTH - 120 - offset, Y: config.MAP_HEIGHT - 180 - offset}
}
