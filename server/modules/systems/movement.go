package systems

import (
	"math"

	"breach3v3/server/modules/config"
	"breach3v3/server/modules/state"
)

type MoveResult struct {
	Accepted bool
	Reason   string
}

func ValidateMove(player *state.Player, next state.Vec2, tickInterval float64) MoveResult {
	if !withinBounds(next) {
		return MoveResult{Reason: "out_of_bounds"}
	}
	if collidesWithObstacle(next, config.PLAYER_COLLISION_RADIUS) {
		return MoveResult{Reason: "solid_collision"}
	}
	maxDistance := config.PLAYER_MAX_SPEED*tickInterval + 1.0
	dx := next.X - player.LastValid.X
	dy := next.Y - player.LastValid.Y
	if math.Hypot(dx, dy) > maxDistance {
		return MoveResult{Reason: "speed_limit"}
	}
	return MoveResult{Accepted: true}
}

func withinBounds(pos state.Vec2) bool {
	radius := config.PLAYER_COLLISION_RADIUS
	return pos.X >= radius &&
		pos.Y >= radius &&
		pos.X <= config.MAP_WIDTH-radius &&
		pos.Y <= config.MAP_HEIGHT-radius
}

func collidesWithObstacle(pos state.Vec2, radius float64) bool {
	for _, obstacle := range config.SOLID_OBSTACLES {
		closestX := clamp(pos.X, obstacle.X, obstacle.X+obstacle.W)
		closestY := clamp(pos.Y, obstacle.Y, obstacle.Y+obstacle.H)
		if math.Hypot(pos.X-closestX, pos.Y-closestY) < radius {
			return true
		}
	}
	return false
}

func clamp(value float64, min float64, max float64) float64 {
	if value < min {
		return min
	}
	if value > max {
		return max
	}
	return value
}
