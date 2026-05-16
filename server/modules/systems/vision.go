package systems

import (
	"math"

	"breach3v3/server/modules/config"
	"breach3v3/server/modules/state"
)

func CanPlayerSee(observer *state.Player, target *state.Player, cfg *config.GameConfig) bool {
	if observer == nil || target == nil || cfg == nil {
		return false
	}
	if observer.UserID != "" && observer.UserID == target.UserID {
		return true
	}
	if !observer.Connected || !target.Connected {
		return false
	}

	character := cfg.Character(observer.CharacterID)
	dx := target.Position.X - observer.Position.X
	dy := target.Position.Y - observer.Position.Y
	distance := math.Hypot(dx, dy)
	if distance > character.VisionConeLength {
		return false
	}
	if lineBlockedByVisionObstacles(cfg, observer.Position, target.Position) {
		return false
	}
	if distance <= character.VisionRadius {
		return true
	}
	if distance == 0 {
		return true
	}

	facing := normalizedDirection(observer.Direction)
	targetDirection := state.Vec2{X: dx / distance, Y: dy / distance}
	dot := facing.X*targetDirection.X + facing.Y*targetDirection.Y
	return dot >= math.Cos(character.VisionConeHalfAngleRad)
}

func lineBlockedByVisionObstacles(cfg *config.GameConfig, a state.Vec2, b state.Vec2) bool {
	if len(cfg.Map.Obstacles) > 0 {
		for _, obstacle := range cfg.Map.Obstacles {
			if obstacle.BlocksVision && segmentIntersectsShape(a, b, obstacle) {
				return true
			}
		}
		return false
	}
	for _, obstacle := range cfg.Map.SolidObstacles {
		if segmentIntersectsRect(a, b, obstacle) {
			return true
		}
	}
	for _, shape := range cfg.Map.CollisionShapes {
		if segmentIntersectsShape(a, b, shape) {
			return true
		}
	}
	return false
}

func normalizedDirection(direction state.Vec2) state.Vec2 {
	length := math.Hypot(direction.X, direction.Y)
	if length == 0 {
		return state.Vec2{X: 1}
	}
	return state.Vec2{X: direction.X / length, Y: direction.Y / length}
}

func segmentIntersectsShape(a state.Vec2, b state.Vec2, shape config.CollisionShape) bool {
	switch shape.Type {
	case "rect":
		return segmentIntersectsRect(a, b, config.Rect{X: shape.X, Y: shape.Y, W: shape.W, H: shape.H})
	case "circle":
		center := state.Vec2{X: shape.X, Y: shape.Y}
		return distancePointToSegment(center, a, b) <= shape.Radius
	case "capsule":
		if shape.A == nil || shape.B == nil {
			return false
		}
		p1 := pointToVec(*shape.A)
		p2 := pointToVec(*shape.B)
		return segmentsIntersect(a, b, p1, p2) || distanceSegmentToSegment(a, b, p1, p2) <= shape.Radius
	case "segment":
		if shape.A == nil || shape.B == nil {
			return false
		}
		return segmentsIntersect(a, b, pointToVec(*shape.A), pointToVec(*shape.B))
	case "polygon":
		return segmentIntersectsPolygon(a, b, shape.Points)
	default:
		return false
	}
}

func segmentIntersectsRect(a state.Vec2, b state.Vec2, rect config.Rect) bool {
	if pointInRect(a, rect) || pointInRect(b, rect) {
		return true
	}
	topLeft := state.Vec2{X: rect.X, Y: rect.Y}
	topRight := state.Vec2{X: rect.X + rect.W, Y: rect.Y}
	bottomLeft := state.Vec2{X: rect.X, Y: rect.Y + rect.H}
	bottomRight := state.Vec2{X: rect.X + rect.W, Y: rect.Y + rect.H}
	return segmentsIntersect(a, b, topLeft, topRight) ||
		segmentsIntersect(a, b, topRight, bottomRight) ||
		segmentsIntersect(a, b, bottomLeft, bottomRight) ||
		segmentsIntersect(a, b, topLeft, bottomLeft)
}

func segmentIntersectsPolygon(a state.Vec2, b state.Vec2, points []config.MapPoint) bool {
	if len(points) < 3 {
		return false
	}
	if pointInPolygon(a, points) || pointInPolygon(b, points) {
		return true
	}
	for i := range points {
		if segmentsIntersect(a, b, pointToVec(points[i]), pointToVec(points[(i+1)%len(points)])) {
			return true
		}
	}
	return false
}

func distanceSegmentToSegment(a state.Vec2, b state.Vec2, c state.Vec2, d state.Vec2) float64 {
	if segmentsIntersect(a, b, c, d) {
		return 0
	}
	return math.Min(
		math.Min(distancePointToSegment(a, c, d), distancePointToSegment(b, c, d)),
		math.Min(distancePointToSegment(c, a, b), distancePointToSegment(d, a, b)),
	)
}

func pointInRect(point state.Vec2, rect config.Rect) bool {
	return point.X >= rect.X &&
		point.X <= rect.X+rect.W &&
		point.Y >= rect.Y &&
		point.Y <= rect.Y+rect.H
}

func segmentsIntersect(p1 state.Vec2, p2 state.Vec2, q1 state.Vec2, q2 state.Vec2) bool {
	d1 := orient(q1, q2, p1)
	d2 := orient(q1, q2, p2)
	d3 := orient(p1, p2, q1)
	d4 := orient(p1, p2, q2)

	if d1*d2 < 0 && d3*d4 < 0 {
		return true
	}
	if d1 == 0 && onSegment(q1, q2, p1) {
		return true
	}
	if d2 == 0 && onSegment(q1, q2, p2) {
		return true
	}
	if d3 == 0 && onSegment(p1, p2, q1) {
		return true
	}
	if d4 == 0 && onSegment(p1, p2, q2) {
		return true
	}
	return false
}

func orient(a state.Vec2, b state.Vec2, c state.Vec2) float64 {
	return (b.X-a.X)*(c.Y-a.Y) - (b.Y-a.Y)*(c.X-a.X)
}

func onSegment(a state.Vec2, b state.Vec2, c state.Vec2) bool {
	return math.Min(a.X, b.X) <= c.X &&
		c.X <= math.Max(a.X, b.X) &&
		math.Min(a.Y, b.Y) <= c.Y &&
		c.Y <= math.Max(a.Y, b.Y)
}
