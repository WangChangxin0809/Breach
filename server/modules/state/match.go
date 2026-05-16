package state

import (
	"sort"
	"time"

	"breach3v3/server/modules/config"

	"github.com/heroiclabs/nakama-common/runtime"
)

type RoundPhase int32

const (
	ROUND_WAITING RoundPhase = 1
	ROUND_PLAYING RoundPhase = 2
	ROUND_ENDED   RoundPhase = 3
)

type MatchState struct {
	Players      map[string]*Player
	Phase        RoundPhase
	RoundStarted time.Time
	RoundEnded   time.Time
	TickRate     int
	GameMatchID  string
	HostUserID   string
	PartyFaction map[string]Faction
	UserParty    map[string]string
	PartySize    map[string]int
}

func NewMatchState() *MatchState {
	cfg := config.Active()
	return &MatchState{
		Players:      make(map[string]*Player),
		Phase:        ROUND_WAITING,
		TickRate:     cfg.Match.TickRate,
		PartyFaction: make(map[string]Faction),
		UserParty:    make(map[string]string),
		PartySize:    make(map[string]int),
	}
}

func (s *MatchState) ConnectedCount() int {
	count := 0
	for _, player := range s.Players {
		if player.Connected {
			count++
		}
	}
	return count
}

func (s *MatchState) ActivePresences() []runtime.Presence {
	presences := make([]runtime.Presence, 0, len(s.Players))
	for _, player := range s.Players {
		if player.Connected && player.Presence != nil {
			presences = append(presences, player.Presence)
		}
	}
	return presences
}

func (s *MatchState) SortedPlayers() []*Player {
	players := make([]*Player, 0, len(s.Players))
	for _, player := range s.Players {
		players = append(players, player)
	}
	sort.Slice(players, func(i, j int) bool {
		return players[i].UserID < players[j].UserID
	})
	return players
}

func (s *MatchState) AssignHost(userID string) string {
	if s.HostUserID == "" {
		s.HostUserID = userID
	}
	return s.HostUserID
}

func (s *MatchState) AssignFaction(userID string) Faction {
	partyID, hasParty := s.UserParty[userID]
	if hasParty {
		if faction, assigned := s.PartyFaction[partyID]; assigned {
			return faction
		}
	}
	attackers := 0
	defenders := 0
	for _, player := range s.Players {
		switch player.Faction {
		case FACTION_ATTACKERS:
			attackers++
		case FACTION_DEFENDERS:
			defenders++
		}
	}
	var faction Faction
	if attackers <= defenders {
		faction = FACTION_ATTACKERS
	} else {
		faction = FACTION_DEFENDERS
	}
	if hasParty {
		s.PartyFaction[partyID] = faction
	}
	return faction
}
