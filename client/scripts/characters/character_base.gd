extends Node2D

# 角色通用基座：所有具体角色（scout/medic/bomber ...）都继承本场景。
# 职责：
#   1. 持有共用组件（Health / HealthBar / Movement / Vision 等）—— 第 2 周起陆续挂载
#   2. 承接服务器权威状态（位置、阵营、血量）并 apply 到本地节点
#   3. 提供两个技能挂载槽（Basic / Ultimate），由子角色场景挂具体技能脚本
# 原则：不写死任何数值；权威数值由服务器 characters.go 决定。

@onready var sprite: Sprite2D = get_node_or_null("Sprite")
@onready var ability_basic: Node = get_node_or_null("AbilitySlot/Basic")
@onready var ability_ultimate: Node = get_node_or_null("AbilitySlot/Ultimate")

var user_id: String = ""
var faction: int = 0

# 服务器权威状态回调：由网络层在收到广播后调用。
# state 键暂定：position / user_id / faction / health（后续随 proto 扩展）。
func apply_authoritative_state(state: Dictionary) -> void:
	if state.has("position"):
		position = state["position"]
	if state.has("user_id"):
		user_id = state["user_id"]
	if state.has("faction"):
		faction = state["faction"]
	# health 字段由 Health 组件自己订阅处理（第 2 周落地）
