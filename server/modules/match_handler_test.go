package main

import (
	"testing"
	"time"

	gamepb "breach3v3/server/modules/protobuf"
	"breach3v3/server/modules/state"
)

func TestBuildGameStateFiltersPlayersByViewerVision(t *testing.T) {
	viewer := &state.Player{
		UserID:      "viewer",
		CharacterID: "recruit",
		Position:    state.Vec2{X: 100, Y: 100},
		Direction:   state.Vec2{X: 1, Y: 0},
		Connected:   true,
	}
	visible := &state.Player{
		UserID:      "visible",
		CharacterID: "recruit",
		Position:    state.Vec2{X: 360, Y: 100},
		Direction:   state.Vec2{X: -1, Y: 0},
		Connected:   true,
	}
	hidden := &state.Player{
		UserID:      "hidden",
		CharacterID: "recruit",
		Position:    state.Vec2{X: 1000, Y: 100},
		Direction:   state.Vec2{X: -1, Y: 0},
		Connected:   true,
	}
	matchState := &state.MatchState{
		Players: map[string]*state.Player{
			viewer.UserID:  viewer,
			visible.UserID: visible,
			hidden.UserID:  hidden,
		},
		Phase: state.ROUND_PLAYING,
	}

	snapshot := buildGameState(matchState, 1, time.Now().UTC(), viewer)

	if !snapshotContainsUser(snapshot, "viewer") {
		t.Fatalf("expected snapshot to include the viewer")
	}
	if !snapshotContainsUser(snapshot, "visible") {
		t.Fatalf("expected snapshot to include visible player")
	}
	if snapshotContainsUser(snapshot, "hidden") {
		t.Fatalf("expected snapshot to exclude hidden player")
	}
}

func snapshotContainsUser(snapshot *gamepb.GameState, userID string) bool {
	for _, player := range snapshot.Players {
		if player.UserId == userID {
			return true
		}
	}
	return false
}
