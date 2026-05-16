package main

import (
	"testing"
	"time"

	gamepb "breach3v3/server/modules/protobuf"
	"breach3v3/server/modules/state"
)

func TestAssignHostKeepsFirstJoinerAsHost(t *testing.T) {
	matchState := state.NewMatchState()
	first := matchState.AssignHost("z-user")
	second := matchState.AssignHost("a-user")

	if first != "z-user" || second != "z-user" || matchState.HostUserID != "z-user" {
		t.Fatalf("expected first joiner to remain host, got first=%q second=%q stored=%q", first, second, matchState.HostUserID)
	}
}

func TestMatchParamsForPartyGroupsIsDeterministic(t *testing.T) {
	params := matchParamsForPartyGroups(map[string][]string{
		"room:z": {"user-c", "user-a", "user-b"},
	})

	groups, ok := params["party_groups"].(map[string]interface{})
	if !ok {
		t.Fatalf("expected party_groups param, got %#v", params["party_groups"])
	}
	users, ok := groups["room:z"].([]interface{})
	if !ok {
		t.Fatalf("expected room party users, got %#v", groups["room:z"])
	}
	got := make([]string, 0, len(users))
	for _, user := range users {
		got = append(got, user.(string))
	}
	want := []string{"user-a", "user-b", "user-c"}
	for i := range want {
		if got[i] != want[i] {
			t.Fatalf("expected deterministic party users %v, got %v", want, got)
		}
	}
}

func TestRoomPartyMembersStayOnSameFaction(t *testing.T) {
	matchState := state.NewMatchState()
	matchState.UserParty["user-a"] = "room:alpha"
	matchState.UserParty["user-b"] = "room:alpha"
	matchState.UserParty["user-c"] = "room:alpha"

	first := matchState.AssignFaction("user-a")
	matchState.Players["user-a"] = &state.Player{UserID: "user-a", Faction: first}
	second := matchState.AssignFaction("user-b")
	matchState.Players["user-b"] = &state.Player{UserID: "user-b", Faction: second}
	third := matchState.AssignFaction("user-c")

	if first != second || second != third {
		t.Fatalf("expected room party to stay on one faction, got %d %d %d", first, second, third)
	}
}

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
