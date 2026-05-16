package systems

import (
	"testing"

	"breach3v3/server/modules/config"
	"breach3v3/server/modules/state"
)

func TestValidateMoveAcceptsLegalMovement(t *testing.T) {
	cfg := config.Active()
	player := &state.Player{
		LastValid: state.Vec2{X: 240, Y: 180},
	}
	next := state.Vec2{X: 248, Y: 180}

	result := ValidateMove(player, next, 1.0/float64(cfg.Match.TickRate))
	if !result.Accepted {
		t.Fatalf("expected legal move to be accepted, got reason %q", result.Reason)
	}
}

func TestValidateMoveRejectsSpeedLimit(t *testing.T) {
	cfg := config.Active()
	player := &state.Player{
		LastValid: state.Vec2{X: 240, Y: 180},
	}
	next := state.Vec2{X: 340, Y: 180}

	result := ValidateMove(player, next, 1.0/float64(cfg.Match.TickRate))
	if result.Accepted || result.Reason != "speed_limit" {
		t.Fatalf("expected speed_limit rejection, got accepted=%v reason=%q", result.Accepted, result.Reason)
	}
}

func TestValidateMoveRejectsBounds(t *testing.T) {
	cfg := config.Active()
	player := &state.Player{
		LastValid: state.Vec2{X: 240, Y: 180},
	}
	next := state.Vec2{X: -1, Y: 180}

	result := ValidateMove(player, next, 1.0/float64(cfg.Match.TickRate))
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

func TestCircleIntersectsExportedPolygon(t *testing.T) {
	shape := config.CollisionShape{
		Type: "polygon",
		Points: []config.MapPoint{
			{X: 100, Y: 100},
			{X: 140, Y: 100},
			{X: 140, Y: 140},
			{X: 100, Y: 140},
		},
	}

	if !collidesWithShape(state.Vec2{X: 120, Y: 120}, 16, shape) {
		t.Fatalf("expected circle center inside polygon to collide")
	}
	if !collidesWithShape(state.Vec2{X: 150, Y: 120}, 16, shape) {
		t.Fatalf("expected circle touching polygon edge to collide")
	}
	if collidesWithShape(state.Vec2{X: 180, Y: 120}, 16, shape) {
		t.Fatalf("expected separated circle to avoid polygon")
	}
}

func TestCircleIntersectsExportedCapsule(t *testing.T) {
	shape := config.CollisionShape{
		Type:   "capsule",
		Radius: 8,
		A:      &config.MapPoint{X: 100, Y: 100},
		B:      &config.MapPoint{X: 180, Y: 100},
	}

	if !collidesWithShape(state.Vec2{X: 140, Y: 120}, 16, shape) {
		t.Fatalf("expected nearby circle to collide with capsule")
	}
	if collidesWithShape(state.Vec2{X: 140, Y: 150}, 16, shape) {
		t.Fatalf("expected distant circle to avoid capsule")
	}
}

func TestSemanticObstaclesOnlyBlockMovementWhenFlagged(t *testing.T) {
	cfg := &config.GameConfig{
		Map: config.MapConfig{
			Obstacles: []config.CollisionShape{
				{
					Type:         "circle",
					X:            100,
					Y:            100,
					Radius:       32,
					BlocksVision: true,
				},
				{
					Type:           "circle",
					X:              200,
					Y:              100,
					Radius:         32,
					BlocksMovement: true,
				},
			},
		},
	}

	if collidesWithObstacle(cfg, state.Vec2{X: 100, Y: 100}, 16) {
		t.Fatalf("expected vision-only obstacle not to block movement")
	}
	if !collidesWithObstacle(cfg, state.Vec2{X: 200, Y: 100}, 16) {
		t.Fatalf("expected movement obstacle to block movement")
	}
}
