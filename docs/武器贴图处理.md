这在 Godot 中是一个非常经典的“水土不服”问题，根本原因在于**你的武器原图朝向与 Godot 的底层数学逻辑产生了冲突**。

### 为什么会这样？

Godot 的 `look_at()` 函数有一个不可更改的数学铁律：**它永远认为节点的“正前方”是 0 度角，即 X 轴的正方向（朝右）**。

你在上一轮沟通中提到过，你的**武器贴图原本是朝向左侧的**。
当代码执行 `weapon_pivot.look_at(mouse_pos)`  时，Godot 会将 `WeaponPivot` 的**右侧**对准鼠标。既然武器的贴图是朝左画的，它自然就会 180 度“背对”着鼠标，造成了方向完全相反的现象。

### 最佳解决思路

我们不需要去修改复杂的数学公式，只需要“欺骗”一下系统：在游戏一开始，**用代码将武器的水平朝向强制翻转为朝右**，让它符合 Godot 的标准。

### 代码修复方案

仔细看你提供的代码，在文件最底部 `_ready()` 函数的上方多了一个孤立的 `func` 关键字，这会导致语法报错。我们需要清理一下，并在 `_ready()` 中加入 `flip_h = true`。

请将你代码底部的这部分：

```gdscript
func 
_ready() -> void:
	var cursor_texture := preload("res://assets/UI/Cursor.png") 
	Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, Vector2(16, 16))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

```

**替换为以下正确代码：**

```gdscript
func _ready() -> void:
	# 【核心修复】因为你的武器原图朝左，这里必须水平翻转它！
	# 只有让武器在逻辑上朝向右边(+X)，look_at() 才能准确对准鼠标。
	weapon_sprite.flip_h = true 

	# 自定义光标配置
	var cursor_texture := preload("res://assets/UI/Cursor.png") 
	Input.set_custom_mouse_cursor(cursor_texture, Input.CURSOR_ARROW, Vector2(16, 16))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

```

**额外检查点（在编辑器中）：**
如果你在 Godot 编辑器（2D 视图）里为了好看，手动把 `WeaponSprite` 的 `Rotation` 调成了 `180`度 或者 `Scale` 设成了 `-1`，请**立刻把它们恢复为默认值**（Rotation 设为 0，Scale 设为 1,1）。所有的翻转和旋转完全交给代码来接管，这样就不会出现逻辑打架导致的方向错乱了。