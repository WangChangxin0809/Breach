package config

const (
	MATCH_MODULE_NAME = "breach_match"

	MATCH_TICK_RATE     = 20
	MATCH_MAX_PLAYERS   = 6
	MATCH_MIN_PLAYERS   = 2
	ROUND_DURATION_SEC  = 120
	ROUND_END_DELAY_SEC = 4
	ROUNDS_PER_HALF     = 6

	MAP_WIDTH  = 1600.0
	MAP_HEIGHT = 960.0

	POINTS_PER_PLAYER_KILL = 100
	POINTS_PER_ZOMBIE_KILL = 25
)

var SOLID_OBSTACLES = []Rect{
	{X: 460, Y: 220, W: 120, H: 260},
	{X: 920, Y: 420, W: 260, H: 120},
	{X: 700, Y: 700, W: 180, H: 90},
}

type Rect struct {
	X float64
	Y float64
	W float64
	H float64
}
