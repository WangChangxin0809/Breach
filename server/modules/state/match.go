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
}

func NewMatchState() *MatchState {
	return &MatchState{
		Players:  make(map[string]*Player),
		Phase:    ROUND_WAITING,
		TickRate: config.MATCH_TICK_RATE,
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
