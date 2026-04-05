extends Control

# ВАЖНО: Этот скрипт ДОЛЖЕН наследоваться от Control, так как сцена LevelSelector.tscn - это Control.

@onready var grid = $GridContainer

var _level_count = 20
var _unlocked_levels = 1

func _ready():
	# Принудительная проверка типа при запуске для отладки
	if not self is Control:
		print("ОШИБКА: Скрипт привязан к узлу, который не является Control!")
		return

	# Переименовываем заголовок, если узел найден
	if has_node("Title"):
		get_node("Title").text = "ВЫБОР МИССИИ"

	if SaveManager != null:
		_unlocked_levels = SaveManager.save_data.get("unlocked_levels", 1)

	_setup_grid()

func _setup_grid():
	if grid == null:
		push_error("GridContainer не найден в сцене LevelSelector!")
		return

	# Очистка старых кнопок
	for child in grid.get_children():
		child.queue_free()

	for i in range(1, _level_count + 1):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 120)
		btn.name = "Level_" + str(i)
		btn.text = str(i)
		btn.add_theme_font_size_override("font_size", 42)

		var is_locked = i > _unlocked_levels

		# Стиль кнопок
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
			style.bg_color = Color(0.2, 0.6, 0.9, 0.9) # Голубой
			style.border_color = Color(1, 1, 1, 0.8)
			btn.pressed.connect(_on_level_pressed.bind(i))

		btn.add_theme_stylebox_override("normal", style)
		btn.add_theme_stylebox_override("disabled", style)
		btn.add_theme_stylebox_override("hover", style)
		btn.add_theme_stylebox_override("pressed", style)

		grid.add_child(btn)

func _on_level_pressed(level_num: int):
	if SaveManager:
		SaveManager.set_meta("current_level", level_num)

	var path = "res://scenes/Levels/Level_" + str(level_num) + ".tscn"
	if FileAccess.file_exists(path):
		get_tree().change_scene_to_file(path)
	else:
		get_tree().change_scene_to_file("res://scenes/Field.tscn")

func _on_Return_Button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
