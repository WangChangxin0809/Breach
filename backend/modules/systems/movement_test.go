package systems

import (
	"testing"

	"breach3v3/backend/modules/config"
	"breach3v3/backend/modules/state"
)

func TestValidateMoveAcceptsLegalMovement(t *testing.T) {
	player := &state.Player{
		LastValid: state.Vec2{X: 120, Y: 180},
	}
	next := state.Vec2{X: 128, Y: 180}

	result := ValidateMove(player, next, 1.0/float64(config.MATCH_TICK_RATE))
	if !result.Accepted {
		t.Fatalf("expected legal move to be accepted, got reason %q", result.Reason)
	}
}

func TestValidateMoveRejectsSpeedLimit(t *testing.T) {
	player := &state.Player{
		LastValid: state.Vec2{X: 120, Y: 180},
	}
	next := state.Vec2{X: 220, Y: 180}

	result := ValidateMove(player, next, 1.0/float64(config.MATCH_TICK_RATE))
	if result.Accepted || result.Reason != "speed_limit" {
		t.Fatalf("expected speed_limit rejection, got accepted=%v reason=%q", result.Accepted, result.Reason)
	}
}

func TestValidateMoveRejectsBounds(t *testing.T) {
	player := &state.Player{
		LastValid: state.Vec2{X: 120, Y: 180},
	}
	next := state.Vec2{X: -1, Y: 180}

	result := ValidateMove(player, next, 1.0/float64(config.MATCH_TICK_RATE))
	if result.Accepted || result.Reason != "out_of_bounds" {
		t.Fatalf("expected out_of_bounds rejection, got accepted=%v reason=%q", result.Accepted, result.Reason)
	}
}

func TestValidateMoveRejectsObstacle(t *testing.T) {
	player := &state.Player{
		LastValid: state.Vec2{X: 480, Y: 210},
	}
	next := state.Vec2{X: 480, Y: 230}

	result := ValidateMove(player, next, 1)
	if result.Accepted || result.Reason != "solid_collision" {
		t.Fatalf("expected solid_collision rejection, got accepted=%v reason=%q", result.Accepted, result.Reason)
	}
}
