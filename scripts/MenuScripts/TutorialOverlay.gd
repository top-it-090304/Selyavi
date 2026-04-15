extends CanvasLayer

signal tutorial_finished

@onready var bg = $Background
@onready var dialog_panel = $Control/DialogPanel
@onready var text_label = $Control/DialogPanel/MarginContainer/Label
@onready var skip_button = $Control/SkipButton

var _current_step = 0
var _last_step_time = 0
var _steps = [
	{"text": "Добро пожаловать, Командир! Рады видеть тебя в строю.", "node": null},
	{"text": "Тебя давно не было видно. Напомню тебе, как здесь все устроено.", "node": null},
	{"text": "Используй этот джойстик для перемещения твоего танка. Лучше не отпускать его надолго!", "node": "Joystick"},
	{"text": "Синий джойстик отвечает за прицеливание и стрельбу. Наведи его на цель, чтобы выстрелить.", "node": "Aim"},
	{"text": "Танк оснащен автодоводкой пушки. Ты можешь отключить ёе в настройках.", "node": "Aim"},
	{"text": "Это наш штаб. Находясь рядом с ним, ты чинишь танк и наносишь больше урона.", "node": "Base"},
	{"text": "Враги будут всеми силами пытаться его уничтожешь. Не допусти это!", "node": "Base"},
	{"text": "Здесь можно переключать типы снарядов. Выбирай подходящий под ситуацию.", "node": "AmmoPanel", "shape": 1},
	{"text": "Каждый снаряд уникален: Плазма - быстрый, средний снаряд - самый мощный, а лёгкий летит дальше всех.", "node": "AmmoPanel", "shape": 1},
	{"text": "Следи за показателями: здесь твое здоровье, количество жизней, заработанные деньги и счетчик баз врага.", "node": "Stats", "shape": 1},
	{"text": "Лучше не дать жизням закончится.", "node": "Stats", "shape": 1},
	{"text": "За деньги ты можешь улучшать свой танк в магазине.", "node": "Stats", "shape": 1},
	{"text": "Маркеры по краям экрана помогут найти босса, врагов и базы вне поля зрения.", "node": "MarkerOverlay"},
	{"text": "Миссия ясна. Уничтожь вражеские базы и защити свою. Удачи в бою!", "node": "MarkerOverlay"}
]

func _ready():
	add_to_group("tutorial")
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	if AudioManager and AudioManager.has_method("play_tutorial"):
		AudioManager.play_tutorial()

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_joysticks_opacity"):
		hud.set_joysticks_opacity(1.0)

	_setup_adaptive_ui()
	_start_step()

func _setup_adaptive_ui():
	if not skip_button: return
	var screen_size = get_viewport().get_visible_rect().size

	# Адаптивный размер кнопки (мин 240px или 15% ширины)
	var btn_width = max(240, screen_size.x * 0.15)
	var btn_height = max(60, screen_size.y * 0.08)

	skip_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	skip_button.anchor_left = 0.0
	skip_button.anchor_top = 0.0
	skip_button.anchor_right = 0.0
	skip_button.anchor_bottom = 0.0

	# Сдвигаем вправо от кнопки паузы (x=18 + ширина кнопки паузы ~120)
	skip_button.offset_left = 140
	skip_button.offset_top = 25
	skip_button.custom_minimum_size = Vector2(btn_width, btn_height)
	skip_button.size = skip_button.custom_minimum_size

func _input(event):
	if (event is InputEventMouseButton and event.pressed) or \
	   (event is InputEventScreenTouch and event.pressed):

		var current_time = Time.get_ticks_msec()
		if current_time - _last_step_time < 250:
			return
		_last_step_time = current_time

		if skip_button and skip_button.get_global_rect().has_point(event.position):
			_on_skip_pressed()
			return
		_next_step()

func _start_step():
	await get_tree().process_frame
	if _current_step >= _steps.size(): return

	var step = _steps[_current_step]
	text_label.text = step.text

	var target_pos = Vector2.ZERO
	var radius = 0.0
	var size = Vector2.ZERO
	var shape = step.get("shape", 0)

	if step.node != null:
		var node = _find_target_node(step.node)
		if node:
			target_pos = _get_node_screen_pos(node)
			if node is Control:
				target_pos = node.get_global_rect().get_center()

			if shape == 0:
				radius = _get_node_radius(node, step.node)
			else:
				var scale = (node as CanvasItem).get_screen_transform().get_scale()
				if node is Control:
					var final_size = node.size
					if node.name == "AmmoPanelContainer":
						var inner = node.find_child("AmmoPanel", true, false)
						if inner: final_size = inner.size
					size = final_size * scale + Vector2(60, 40)
				else:
					size = Vector2(120, 120) * scale

	_adjust_dialog_position(target_pos)
	_update_shader_params(target_pos, radius, size, shape)

func _adjust_dialog_position(target_pos: Vector2):
	var screen_size = get_viewport().get_visible_rect().size

	# Ширина панели до 85% экрана, но не более 1000px
	var panel_width = min(1000, screen_size.x * 0.85)
	dialog_panel.custom_minimum_size.x = panel_width
	dialog_panel.offset_left = -panel_width / 2.0
	dialog_panel.offset_right = panel_width / 2.0

	# Адаптивный отступ по вертикали (5% высоты)
	var margin_y = screen_size.y * 0.05

	if target_pos != Vector2.ZERO and target_pos.y > screen_size.y * 0.5:
		# Цель в нижней половине -> панель наверх, но ниже кнопок управления
		dialog_panel.anchor_top = 0.0
		dialog_panel.anchor_bottom = 0.0
		dialog_panel.offset_top = margin_y + 100
		dialog_panel.offset_bottom = dialog_panel.offset_top + 220
	else:
		# Цель в верхней половине -> панель вниз
		dialog_panel.anchor_top = 1.0
		dialog_panel.anchor_bottom = 1.0
		dialog_panel.offset_bottom = -margin_y
		dialog_panel.offset_top = -margin_y - 220

func _update_shader_params(pos, rad, sz, shp):
	var mat = bg.material as ShaderMaterial
	if mat:
		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
		var cur_center = mat.get_shader_parameter("hole_center")
		if not (cur_center is Vector2): cur_center = pos
		var cur_radius = mat.get_shader_parameter("hole_radius")
		if not (cur_radius is float): cur_radius = 0.0
		var cur_size = mat.get_shader_parameter("hole_size")
		if not (cur_size is Vector2): cur_size = Vector2.ZERO
		var cur_shape = mat.get_shader_parameter("shape")
		if not (cur_shape is float): cur_shape = 0.0

		tween.tween_method(func(v): mat.set_shader_parameter("hole_center", v), cur_center, pos, 0.4)
		tween.tween_method(func(v): mat.set_shader_parameter("hole_radius", v), cur_radius, rad, 0.4)
		tween.tween_method(func(v): mat.set_shader_parameter("hole_size", v), cur_size, sz, 0.4)
		tween.tween_method(func(v): mat.set_shader_parameter("shape", v), float(cur_shape), float(shp), 0.2)

func _find_target_node(node_name: String):
	if node_name == "Base":
		var bases = get_tree().get_nodes_in_group("bases")
		for b in bases: if b.get("type_base") == 0: return b
		return null

	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		# Ищем джойстики в контейнерах, так как сами джойстики могут иметь нулевой размер
		if node_name == "Joystick": return hud.find_child("MoveJoystickContainer", true)
		if node_name == "Aim": return hud.find_child("AimJoystickContainer", true)
		if node_name == "AmmoPanel":
			var apc = hud.find_child("AmmoPanelContainer", true, false)
			return apc if apc else hud.find_child("AmmoPanel", true, false)
		if node_name == "Stats": return hud.find_child("TopRight", true)
		if node_name == "MarkerOverlay": return hud.find_child("MarkerOverlay", true, false)
	return null

func _get_node_screen_pos(node: Node) -> Vector2:
	if node is Control:
		return node.get_screen_transform().get_origin() + (node.size * node.get_screen_transform().get_scale() / 2.0)
	if node is Node2D:
		return node.get_global_transform_with_canvas().get_origin()
	return Vector2.ZERO

func _get_node_radius(node: Node, node_name: String) -> float:
	if node_name == "Base": return 120.0
	if node is Control:
		var scale = (node as CanvasItem).get_screen_transform().get_scale().x
		return max(node.size.x, node.size.y) * scale * 0.6
	return 100.0

func _next_step():
	_current_step += 1
	if _current_step >= _steps.size(): _finish_tutorial()
	else: _start_step()

func _on_skip_pressed(): _finish_tutorial()

func _finish_tutorial():
	get_tree().paused = false

	# Возвращаем прозрачность джойстикам (0.3 - стандартное значение)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_joysticks_opacity"):
		hud.set_joysticks_opacity(0.3)

	if AudioManager:
		if AudioManager.has_method("stop_tutorial"): AudioManager.stop_tutorial()
		elif AudioManager.has_method("stop"): AudioManager.stop()
	tutorial_finished.emit()
	queue_free()
