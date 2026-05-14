package state

import "github.com/heroiclabs/nakama-common/runtime"

type Faction int32

const (
	FACTION_ATTACKERS Faction = 1
	FACTION_DEFENDERS Faction = 2
)

type Vec2 struct {
	X float64
	Y float64
}

type Player struct {
	UserID          string
	SessionID       string
	Username        string
	DisplayName     string
	CharacterID     string
	CharacterLocked bool
	Faction         Faction
	Position        Vec2
	LastValid       Vec2
	Health          int
	Connected       bool
	Presence        runtime.Presence
}
