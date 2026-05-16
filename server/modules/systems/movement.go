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
	cfg := config.Active()
	character := cfg.Character(player.CharacterID)
	if !withinBounds(cfg, character, next) {
		return MoveResult{Reason: "out_of_bounds"}
	}
	if collidesWithObstacle(cfg, next, character.CollisionRadius) {
		return MoveResult{Reason: "solid_collision"}
	}
	maxDistance := character.MaxSpeed*tickInterval + 1.0
	dx := next.X - player.LastValid.X
	dy := next.Y - player.LastValid.Y
	if math.Hypot(dx, dy) > maxDistance {
		return MoveResult{Reason: "speed_limit"}
	}
	return MoveResult{Accepted: true}
}

func withinBounds(cfg *config.GameConfig, character config.CharacterConfig, pos state.Vec2) bool {
	radius := character.CollisionRadius
	return pos.X >= radius &&
		pos.Y >= radius &&
		pos.X <= cfg.Map.Width-radius &&
		pos.Y <= cfg.Map.Height-radius
}

func collidesWithObstacle(cfg *config.GameConfig, pos state.Vec2, radius float64) bool {
	if len(cfg.Map.Obstacles) > 0 {
		for _, obstacle := range cfg.Map.Obstacles {
			if obstacle.BlocksMovement && collidesWithShape(pos, radius, obstacle) {
				return true
			}
		}
		return false
	}
	for _, obstacle := range cfg.Map.SolidObstacles {
		closestX := clamp(pos.X, obstacle.X, obstacle.X+obstacle.W)
		closestY := clamp(pos.Y, obstacle.Y, obstacle.Y+obstacle.H)
		if math.Hypot(pos.X-closestX, pos.Y-closestY) < radius {
			return true
		}
	}
	for _, shape := range cfg.Map.CollisionShapes {
		if collidesWithShape(pos, radius, shape) {
			return true
		}
	}
	return false
}

func collidesWithShape(pos state.Vec2, radius float64, shape config.CollisionShape) bool {
	switch shape.Type {
	case "rect":
		closestX := clamp(pos.X, shape.X, shape.X+shape.W)
		closestY := clamp(pos.Y, shape.Y, shape.Y+shape.H)
		return math.Hypot(pos.X-closestX, pos.Y-closestY) < radius
	case "circle":
		return math.Hypot(pos.X-shape.X, pos.Y-shape.Y) < radius+shape.Radius
	case "capsule":
		if shape.A == nil || shape.B == nil {
			return false
		}
		return distancePointToSegment(pos, pointToVec(*shape.A), pointToVec(*shape.B)) < radius+shape.Radius
	case "segment":
		if shape.A == nil || shape.B == nil {
			return false
		}
		return distancePointToSegment(pos, pointToVec(*shape.A), pointToVec(*shape.B)) < radius
	case "polygon":
		return circleIntersectsPolygon(pos, radius, shape.Points)
	default:
		return false
	}
}

func circleIntersectsPolygon(center state.Vec2, radius float64, points []config.MapPoint) bool {
	if len(points) < 3 {
		return false
	}
	if pointInPolygon(center, points) {
		return true
	}
	for i := range points {
		a := pointToVec(points[i])
		b := pointToVec(points[(i+1)%len(points)])
		if distancePointToSegment(center, a, b) < radius {
			return true
		}
	}
	return false
}

func pointInPolygon(point state.Vec2, polygon []config.MapPoint) bool {
	inside := false
	j := len(polygon) - 1
	for i := range polygon {
		pi := polygon[i]
		pj := polygon[j]
		intersects := (pi.Y > point.Y) != (pj.Y > point.Y)
		if intersects {
			xAtY := (pj.X-pi.X)*(point.Y-pi.Y)/(pj.Y-pi.Y) + pi.X
			if point.X < xAtY {
				inside = !inside
			}
		}
		j = i
	}
	return inside
}

func distancePointToSegment(point state.Vec2, a state.Vec2, b state.Vec2) float64 {
	abX := b.X - a.X
	abY := b.Y - a.Y
	lengthSquared := abX*abX + abY*abY
	if lengthSquared == 0 {
		return math.Hypot(point.X-a.X, point.Y-a.Y)
	}
	t := ((point.X-a.X)*abX + (point.Y-a.Y)*abY) / lengthSquared
	t = clamp(t, 0, 1)
	closestX := a.X + t*abX
	closestY := a.Y + t*abY
	return math.Hypot(point.X-closestX, point.Y-closestY)
}

func pointToVec(point config.MapPoint) state.Vec2 {
	return state.Vec2{X: point.X, Y: point.Y}
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
