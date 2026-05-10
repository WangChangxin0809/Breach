extends CanvasLayer

# HUD 血条：屏幕下方中部固定显示本地玩家血量。
# 职责：纯表现层，提供 set_health() 接口供上层调用（第 2 周生命值模块接入）。
# 不订阅任何权威状态，具体数据源由 Health 组件或网络层决定。

const BAR_WIDTH := 320.0
const TWEEN_DURATION := 0.18
const HEALTHY_COLOR := Color(0.2, 0.85, 0.3, 1.0)
const LOW_HEALTH_COLOR := Color(0.92, 0.23, 0.18, 1.0)
const DEAD_COLOR := Color(0.35, 0.35, 0.35, 1.0)

@onready var bar_fill: ColorRect = get_node_or_null("Root/BarFill")
@onready var hp_label: Label = get_node_or_null("Root/HPLabel")

var max_health: int = 100
var current_health: int = 100
var health_tween: Tween

func _ready() -> void:
	_refresh(false)

func set_health(current: int, maximum: int = -1) -> void:
	if maximum > 0:
		max_health = maximum
	current_health = clampi(current, 0, max_health)
	_refresh(true)

func _refresh(animated: bool) -> void:
	if bar_fill == null or hp_label == null:
		return
	var ratio: float = 0.0
	if max_health > 0:
		ratio = clampf(float(current_health) / float(max_health), 0.0, 1.0)
	var target_width := BAR_WIDTH * ratio
	var target_color := _health_color(ratio)
	if health_tween:
		health_tween.kill()
	if animated:
		health_tween = create_tween()
		health_tween.set_parallel(true)
		health_tween.tween_property(bar_fill, "size:x", target_width, TWEEN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		health_tween.tween_property(bar_fill, "color", target_color, TWEEN_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		bar_fill.size.x = target_width
		bar_fill.color = target_color
	hp_label.text = "HP %d / %d" % [current_health, max_health]

func _health_color(ratio: float) -> Color:
	if current_health <= 0:
		return DEAD_COLOR
	if ratio <= 0.3:
		return LOW_HEALTH_COLOR
	return HEALTHY_COLOR
