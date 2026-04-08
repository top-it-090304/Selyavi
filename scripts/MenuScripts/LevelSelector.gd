extends Control

@onready var scroll_container = $UI/CenterContainer/LevelScroll
@onready var grid = $UI/CenterContainer/LevelScroll/GridContainer

var _level_count = 20
var _unlocked_levels = 1

# Параметры для плавной прокрутки
var target_scroll = 0.0
var scroll_speed = 0.15 # Чем меньше, тем плавнее (0.1 - 0.2 оптимально)

func _ready():
	if not self is Control:
		return

	if has_node("UI/Title"):
		get_node("UI/Title").text = "ВЫБОР МИССИИ"

	if SaveManager != null:
		_unlocked_levels = SaveManager.save_data.get("unlocked_levels", 1)

	_setup_grid()

	# Инициализируем целевую позицию прокрутки
	if scroll_container:
		target_scroll = scroll_container.scroll_vertical
		# Соединяем сигнал ввода для перехвата колесика мыши
		scroll_container.gui_input.connect(_on_scroll_input)

func _process(_delta):
	if scroll_container:
		# Плавное приближение текущей прокрутки к целевой
		var current = scroll_container.scroll_vertical
		if abs(current - target_scroll) > 0.1:
			scroll_container.scroll_vertical = lerp(current, int(target_scroll), scroll_speed)
		else:
			scroll_container.scroll_vertical = int(target_scroll)

func _on_scroll_input(event):
	if event is InputEventMouseButton:
		var step = 150 # Размер шага прокрутки
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_scroll -= step
			_clamp_scroll()
			accept_event() # Поглощаем событие, чтобы стандартная прокрутка не дергалась
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_scroll += step
			_clamp_scroll()
			accept_event()

	# Если пользователь тянет пальцем или мышкой (Drag), обновляем цель, чтобы не было конфликтов
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		target_scroll = scroll_container.scroll_vertical

func _clamp_scroll():
	if not scroll_container: return
	var max_scroll = scroll_container.get_v_scroll_bar().max_value - scroll_container.size.y
	target_scroll = clamp(target_scroll, 0, max_scroll)

func _setup_grid():
	if grid == null:
		push_error("GridContainer не найден!")
		return

	for child in grid.get_children():
		child.queue_free()

	for i in range(1, _level_count + 1):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 120)
		btn.name = "Level_" + str(i)

		var major = ((i - 1) / 5) + 1
		var minor = ((i - 1) % 5) + 1
		btn.text = str(major) + "." + str(minor)
		btn.add_theme_font_size_override("font_size", 34)

		var is_locked = i > _unlocked_levels
		var is_passed = i < _unlocked_levels
		var is_boss = (i % 5 == 0)

		var style = StyleBoxFlat.new()
		style.corner_radius_top_left = 15
		style.corner_radius_top_right = 15
		style.corner_radius_bottom_left = 15
		style.corner_radius_bottom_right = 15
		style.border_width_left = 4
		style.border_width_top = 4
		style.border_width_right = 4
		style.border_width_bottom = 4

		if is_locked:
			style.bg_color = Color(0.2, 0.2, 0.2, 0.8)
			style.border_color = Color(0.1, 0.1, 0.1)
			btn.disabled = true
			btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
		else:
			if is_boss:
				if is_passed:
					style.bg_color = Color(0.35, 0.1, 0.1, 0.9)
					style.border_color = Color(0.5, 0.2, 0.2, 0.8)
					btn.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
				else:
					style.bg_color = Color(0.7, 0.1, 0.1, 0.9)
					style.border_color = Color(1, 0.2, 0.2, 1)
					btn.add_theme_color_override("font_color", Color(1, 1, 1))
					style.shadow_color = Color(0.5, 0, 0, 0.6)
					style.shadow_size = 8
			else:
				style.bg_color = Color(0.2, 0.6, 0.9, 0.9)
				style.border_color = Color(1, 1, 1, 0.8)
				if is_passed:
					btn.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))

			btn.pressed.connect(_on_level_pressed.bind(i))

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("disabled", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

		grid.add_child(btn)

func _on_level_pressed(level_num: int):
	if SaveManager:
		SaveManager.current_level = level_num
		# Сохраняем и в мету на всякий случай
		SaveManager.set_meta("current_level", level_num)

	# Используем ResourceLoader.exists, чтобы уровни находились после экспорта (в APK)
	var path = "res://scenes/Levels/Level_" + str(level_num) + ".tscn"
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		# Если .tscn не найден (в экспорте он может быть .scn или .res), пробуем без расширения или просто проверяем лоадером
		# ResourceLoader.exists достаточно умен, чтобы понять подмену расширений при экспорте
		get_tree().change_scene_to_file("res://scenes/Field.tscn")

func _on_Return_Button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
