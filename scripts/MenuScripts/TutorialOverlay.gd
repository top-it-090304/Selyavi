extends CanvasLayer

signal tutorial_finished

@onready var bg = $Background
@onready var dialog_panel = $Control/DialogPanel
@onready var text_label = $Control/DialogPanel/MarginContainer/Label
@onready var skip_button = $Control/SkipButton

var _current_step = 0
var _last_step_time = 0
var _steps = [
	{"text": "Добро пожаловать, Командир! Рад видеть тебя в строю."},
	{"text": "Тебя давно не было видно. Напомню тебе, как здесь все устроено."},
	{"text": "Джойстик в левом нижнем углу экрана служит для перемещения твоего танка. Старайся не отпускать его надолго!"},
	{"text": "Синий джойстик справа отвечает за прицеливание и стрельбу. Удерживай его, чтобы выстрелить."},
	{"text": "Твой танк оснащен автодоводкой пушки. Её можно отключить в настройках."},
	{"text": "Зеленое здание сверху — это твой штаб. Находясь около него, ты постепенно чинишь танк и наносишь больше урона."},
	{"text": "Враги будут всеми силами пытаться уничтожить твой штаб. Не допусти этого!"},
	{"text": "В нижней части экрана расположена панель выбора снарядов. Переключай их в зависимости от ситуации."},
	{"text": "Каждый тип снаряда уникален. Экспериментируй, чтобы лучше выходить из разных ситуаций."},
	{"text": "В правом верхнем углу отображаются твои показатели: здоровье, количество жизней, деньги и счетчик вражеских баз."},
	{"text": "Следи за количеством жизней — если они закончатся, миссия будет провалена."},
	{"text": "За заработанные деньги ты сможешь улучшать свой танк в магазине."},
	{"text": "Цветные маркеры по краям экрана помогут тебе найти боссов, врагов и штабы, которые находятся вне поля зрения."},
	{"text": "Твоя задача: уничтожить все вражеские штабы и защитить свой. Удачи в бою!"}
]

func _ready():
	add_to_group("tutorial")
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	# Убираем шейдер и затемнение
	if bg:
		bg.material = null
		bg.color = Color(0, 0, 0, 0) # Полностью прозрачный фон

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

	var btn_width = max(240, screen_size.x * 0.15)
	var btn_height = max(60, screen_size.y * 0.08)

	skip_button.set_anchors_preset(Control.PRESET_TOP_LEFT)
	skip_button.anchor_left = 0.0
	skip_button.anchor_top = 0.0
	skip_button.anchor_right = 0.0
	skip_button.anchor_bottom = 0.0

	skip_button.offset_left = 140
	skip_button.offset_top = 25
	skip_button.custom_minimum_size = Vector2(btn_width, btn_height)
	skip_button.size = skip_button.custom_minimum_size

	# Настраиваем размер диалоговой панели
	var panel_width = min(1000, screen_size.x * 0.85)
	dialog_panel.custom_minimum_size.x = panel_width
	dialog_panel.offset_left = -panel_width / 2.0
	dialog_panel.offset_right = panel_width / 2.0

	# Размещаем панель внизу по умолчанию
	dialog_panel.anchor_top = 1.0
	dialog_panel.anchor_bottom = 1.0
	var margin_y = screen_size.y * 0.05
	dialog_panel.offset_bottom = -margin_y
	dialog_panel.offset_top = -margin_y - 220

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
	if _current_step >= _steps.size(): return
	var step = _steps[_current_step]
	text_label.text = step.text

	# Меняем положение панели в зависимости от шага, чтобы не мешать обзору
	# (например, на шагах про снаряды и джойстики поднимаем панель вверх)
	var screen_size = get_viewport().get_visible_rect().size
	var margin_y = screen_size.y * 0.05

	if _current_step in [2, 3, 7, 8]: # Шаги про джойстики и панель снарядов (внизу)
		dialog_panel.anchor_top = 0.0
		dialog_panel.anchor_bottom = 0.0
		dialog_panel.offset_top = margin_y + 100
		dialog_panel.offset_bottom = dialog_panel.offset_top + 220
	else:
		dialog_panel.anchor_top = 1.0
		dialog_panel.anchor_bottom = 1.0
		dialog_panel.offset_bottom = -margin_y
		dialog_panel.offset_top = -margin_y - 220

func _next_step():
	_current_step += 1
	if _current_step >= _steps.size(): _finish_tutorial()
	else: _start_step()

func _on_skip_pressed(): _finish_tutorial()

func _finish_tutorial():
	get_tree().paused = false

	var hud = get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("set_joysticks_opacity"):
		hud.set_joysticks_opacity(0.3)

	if AudioManager:
		if AudioManager.has_method("stop_tutorial"): AudioManager.stop_tutorial()
		elif AudioManager.has_method("stop"): AudioManager.stop()
	tutorial_finished.emit()
	queue_free()
