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

	# Запускаем музыку обучения
	if AudioManager:
		AudioManager.play_tutorial()

	# Принудительно делаем джойстики непрозрачными для обучения
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_joysticks_opacity"):
		hud.set_joysticks_opacity(1.0)

	if skip_button:
		skip_button.text = "ПРОПУСТИТЬ"
		skip_button.position = Vector2(230, 15)
		skip_button.custom_minimum_size = Vector2(250, 70)

	_start_step()

func _input(event):
	if event is InputEventMouseButton and event.pressed or \
	   event is InputEventScreenTouch and event.pressed:

		var current_time = Time.get_ticks_msec()
		if current_time - _last_step_time < 250:
			return
		_last_step_time = current_time

		if skip_button and skip_button.get_global_rect().has_point(event.position):
			return
		_next_step()

func _start_step():
	# Даем время UI обновиться, чтобы точно найти координаты и размеры узлов
	await get_tree().process_frame

	var step = _steps[_current_step]
	text_label.text = step.text
	text_label.add_theme_constant_override("line_spacing", 10)
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var target_pos = Vector2.ZERO
	var radius = 0.0
	var size = Vector2.ZERO
	var shape = step.get("shape", 0)

	if step.node != null:
		var node = _find_target_node(step.node)
		if node:
			target_pos = _get_node_screen_pos(node)

			# Теперь смещения рассчитываются в процентах от размера узла (адаптивно)
			if node is Control:
				var node_scale = node.get_screen_transform().get_scale()
				var actual_size = node.size * node_scale

				# 5 пикселей левее/правее и 15 выше при размере ~200px — это примерно 2.5% и 7.5%
				# Используем эти пропорции для сохранения "идеального" вида на любом экране
				if step.node == "Aim":
					target_pos += Vector2(actual_size.x * 0.025, actual_size.y * 0.075)
				elif step.node == "Joystick":
					target_pos += Vector2(actual_size.x * 0.025, actual_size.y * 0.075)

			if shape == 0:
				radius = _get_node_radius(node, step.node)
			else:
				# ПРЯМОУГОЛЬНИК: Увеличиваем запас (padding), чтобы шейдер был лучше виден
				var scale = node.get_screen_transform().get_scale()
				size = node.size * scale + Vector2(60, 40)

	_adjust_dialog_position(target_pos)
	_update_shader_params(target_pos, radius, size, shape)

func _adjust_dialog_position(target_pos: Vector2):
	var screen_height = get_viewport().get_visible_rect().size.y

	dialog_panel.anchor_left = 0.5
	dialog_panel.anchor_right = 0.5
	dialog_panel.offset_left = -450
	dialog_panel.offset_right = 450

	# Если цель в нижней половине экрана (как AmmoPanel), диалог уходит вверх
	if target_pos != Vector2.ZERO and target_pos.y > screen_height * 0.5:
		dialog_panel.anchor_top = 0.0
		dialog_panel.anchor_bottom = 0.0
		dialog_panel.offset_top = 150
		dialog_panel.offset_bottom = 350
	else:
		dialog_panel.anchor_top = 1.0
		dialog_panel.anchor_bottom = 1.0
		dialog_panel.offset_top = -250
		dialog_panel.offset_bottom = -50

func _update_shader_params(pos, rad, sz, shp):
	var mat = bg.material as ShaderMaterial
	if mat:
		var current_center = mat.get_shader_parameter("hole_center")
		if current_center == null: current_center = Vector2.ZERO
		var current_radius = mat.get_shader_parameter("hole_radius")
		if current_radius == null: current_radius = 0.0
		var current_size = mat.get_shader_parameter("hole_size")
		if current_size == null: current_size = Vector2.ZERO
		var current_shape = mat.get_shader_parameter("shape")
		if current_shape == null: current_shape = 0.0

		var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
		tween.tween_method(func(v): mat.set_shader_parameter("hole_center", v), current_center, pos, 0.4)
		tween.tween_method(func(v): mat.set_shader_parameter("hole_radius", v), current_radius, rad, 0.4)
		tween.tween_method(func(v): mat.set_shader_parameter("hole_size", v), current_size, sz, 0.4)
		tween.tween_method(func(v): mat.set_shader_parameter("shape", v), current_shape, float(shp), 0.2)

func _find_target_node(node_name: String):
	if node_name == "Base":
		var bases = get_tree().get_nodes_in_group("bases")
		for b in bases: if b.get("type_base") == 0: return b
		return null

	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		var found = hud.find_child(node_name, true, false)
		if found: return found
		# Дополнительные проверки, если find_child не сработал напрямую
		if node_name == "AmmoPanel": return hud.find_child("AmmoPanel", true)
		if node_name == "Stats": return hud.find_child("Stats", true)
		if node_name == "MarkerOverlay": return hud.find_child("MarkerOverlay", true)
	return null

func _get_node_screen_pos(node: Node) -> Vector2:
	if node is Control: return node.get_screen_transform().get_origin() + (node.size * node.get_screen_transform().get_scale() / 2.0)
	elif node is Node2D: return node.get_viewport_transform() * node.global_position
	return Vector2.ZERO

func _get_node_radius(node: Node, node_name: String) -> float:
	if node is Control:
		var scale = node.get_screen_transform().get_scale().x
		var base_radius = max(node.size.x, node.size.y) * 0.5

		# Увеличиваем радиус для джойстиков
		if node_name == "Aim": return base_radius * 1.5 * scale
		if node_name == "Joystick": return base_radius * 1.3 * scale

		# Для маркеров делаем огромный радиус, чтобы убрать темноту
		if node_name == "MarkerOverlay": return 2000.0

		return base_radius * 0.7 * scale
	return 180.0

func _next_step():
	_current_step += 1
	if _current_step >= _steps.size(): _finish()
	else: _start_step()

func _on_skip_pressed(): _finish()

func _finish():
	get_tree().paused = false
	SaveManager.save_data["tutorial_completed"] = true
	SaveManager.save_game()

	# Возвращаем прозрачность джойстикам после обучения
	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_joysticks_opacity"):
		hud.set_joysticks_opacity(0.3)

	# Останавливаем музыку обучения после завершения
	if AudioManager:
		AudioManager.stop()

	tutorial_finished.emit()
	queue_free()
