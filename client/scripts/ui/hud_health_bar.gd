extends CanvasLayer

# HUD 血条：屏幕下方中部固定显示本地玩家血量。
# 职责：纯表现层，提供 set_health() 接口供上层调用（第 2 周生命值模块接入）。
# 不订阅任何权威状态，具体数据源由 Health 组件或网络层决定。

const BAR_WIDTH := 320.0

@onready var bar_fill: ColorRect = get_node_or_null("Root/BarFill")
@onready var hp_label: Label = get_node_or_null("Root/HPLabel")

var max_health: int = 100
var current_health: int = 100

func _ready() -> void:
	_refresh()

func set_health(current: int, maximum: int = -1) -> void:
	if maximum > 0:
		max_health = maximum
	current_health = clampi(current, 0, max_health)
	_refresh()

func _refresh() -> void:
	if bar_fill == null or hp_label == null:
		return
	var ratio: float = 0.0
	if max_health > 0:
		ratio = clampf(float(current_health) / float(max_health), 0.0, 1.0)
	bar_fill.size.x = BAR_WIDTH * ratio
	hp_label.text = "HP %d / %d" % [current_health, max_health]
