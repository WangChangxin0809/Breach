package systems

import (
	"testing"

	"breach3v3/server/modules/config"
	"breach3v3/server/modules/state"
)

func TestCanPlayerSeeUsesShortRangeWithoutFacing(t *testing.T) {
	cfg := visionTestConfig(nil)
	observer := visionTestPlayer("observer", state.Vec2{X: 100, Y: 100}, state.Vec2{X: 1, Y: 0})
	target := visionTestPlayer("target", state.Vec2{X: 100, Y: 145}, state.Vec2{X: -1, Y: 0})

	if !CanPlayerSee(observer, target, cfg) {
		t.Fatalf("expected target inside short-range vision to be visible")
	}
}

func TestCanPlayerSeeUsesForwardCone(t *testing.T) {
	cfg := visionTestConfig(nil)
	observer := visionTestPlayer("observer", state.Vec2{X: 100, Y: 100}, state.Vec2{X: 1, Y: 0})
	target := visionTestPlayer("target", state.Vec2{X: 420, Y: 100}, state.Vec2{X: -1, Y: 0})

	if !CanPlayerSee(observer, target, cfg) {
		t.Fatalf("expected target inside forward cone to be visible")
	}
}

func TestCanPlayerSeeRejectsBehindOutsideShortRange(t *testing.T) {
	cfg := visionTestConfig(nil)
	observer := visionTestPlayer("observer", state.Vec2{X: 100, Y: 100}, state.Vec2{X: 1, Y: 0})
	target := visionTestPlayer("target", state.Vec2{X: 20, Y: 100}, state.Vec2{X: 1, Y: 0})

	if CanPlayerSee(observer, target, cfg) {
		t.Fatalf("expected target behind observer and outside small short-range vision to be hidden")
	}
}

func TestCanPlayerSeeRejectsOutsideCone(t *testing.T) {
	cfg := visionTestConfig(nil)
	observer := visionTestPlayer("observer", state.Vec2{X: 100, Y: 100}, state.Vec2{X: 1, Y: 0})
	target := visionTestPlayer("target", state.Vec2{X: 350, Y: 350}, state.Vec2{X: -1, Y: 0})

	if CanPlayerSee(observer, target, cfg) {
		t.Fatalf("expected target outside forward cone to be hidden")
	}
}

func TestCanPlayerSeeRejectsBlockedLineOfSight(t *testing.T) {
	cfg := visionTestConfig([]config.CollisionShape{
		{
			Type:         "rect",
			X:            200,
			Y:            80,
			W:            40,
			H:            80,
			BlocksVision: true,
		},
	})
	observer := visionTestPlayer("observer", state.Vec2{X: 100, Y: 100}, state.Vec2{X: 1, Y: 0})
	target := visionTestPlayer("target", state.Vec2{X: 360, Y: 100}, state.Vec2{X: -1, Y: 0})

	if CanPlayerSee(observer, target, cfg) {
		t.Fatalf("expected target behind vision-blocking obstacle to be hidden")
	}
}

func TestCanPlayerSeeIgnoresMovementOnlyCover(t *testing.T) {
	cfg := visionTestConfig([]config.CollisionShape{
		{
			Type:           "rect",
			X:              200,
			Y:              80,
			W:              40,
			H:              80,
			BlocksMovement: true,
		},
	})
	observer := visionTestPlayer("observer", state.Vec2{X: 100, Y: 100}, state.Vec2{X: 1, Y: 0})
	target := visionTestPlayer("target", state.Vec2{X: 360, Y: 100}, state.Vec2{X: -1, Y: 0})

	if !CanPlayerSee(observer, target, cfg) {
		t.Fatalf("expected movement-only obstacle not to block vision")
	}
}

func visionTestConfig(obstacles []config.CollisionShape) *config.GameConfig {
	return &config.GameConfig{
		DefaultCharacterID: "recruit",
		Characters: map[string]config.CharacterConfig{
			"recruit": {
				ID:                     "recruit",
				BaseHealth:             100,
				MaxSpeed:               220,
				CollisionRadius:        16,
				VisionRadius:           48,
				VisionConeLength:       420,
				VisionConeHalfAngleRad: config.DefaultVisionConeHalfAngleRad,
			},
		},
		Map: config.MapConfig{
			Width:     1600,
			Height:    960,
			Obstacles: obstacles,
		},
	}
}

func visionTestPlayer(userID string, position state.Vec2, direction state.Vec2) *state.Player {
	return &state.Player{
		UserID:      userID,
		CharacterID: "recruit",
		Position:    position,
		Direction:   direction,
		Connected:   true,
	}
}
