extends RefCounted
class_name Config

const SERVER_KEY := "defaultkey"
const SERVER_HOST := "127.0.0.1"
const SERVER_PORT := 7350
const MATCH_NAME := "breach_match"
const RPC_CREATE_MATCH := "create_breach_match"
const MATCHMAKER_QUERY := "*"
const MATCHMAKER_MIN_PLAYERS := 2
const MATCHMAKER_MAX_PLAYERS := 6
const PARTY_MAX_SIZE := 3
const PARTY_OP_READY := 1
const PARTY_OP_MATCHMAKING := 2

const PROTOCOL_VERSION := 1
const OP_MOVE := 1
const OP_GAME_STATE := 2
const OP_CHARACTER_SELECT := 3
const OP_CHARACTER_SELECT_STATE := 4
const OP_ROOM_READY := 5
const OP_ROOM_STATE := 6
const OP_ROOM_START_MATCH := 7

const PLAYER_MOVE_SPEED := 220.0
const PLAYER_RADIUS := 16.0
const MAP_SIZE := Vector2(1600.0, 960.0)

# 视野系统参数（与服务端 config/characters.go 保持一致）
const VISION_RADIUS := 180.0       # 圆形视野半径，不看朝向
const VISION_CONE := 420.0         # 锥形视野最大距离
const VISION_CONE_HALF_ANGLE := 0.5235987756  # 锥形半角 30°

const FACTION_ATTACKERS := 1
const FACTION_DEFENDERS := 2

const ROUND_WAITING := 1
const ROUND_PLAYING := 2
const ROUND_ENDED := 3

const SOLID_OBSTACLES := [
	Rect2(460.0, 220.0, 120.0, 260.0),
	Rect2(920.0, 420.0, 260.0, 120.0),
	Rect2(700.0, 700.0, 180.0, 90.0),
]
