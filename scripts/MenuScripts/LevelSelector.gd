extends Control

@onready var scroll_container = $UI/CenterContainer/LevelScroll
@onready var grid = $UI/CenterContainer/LevelScroll/GridContainer

var _level_count = 20
var _unlocked_levels = 1

# Параметры для плавной прокрутки
var target_scroll = 0.0
var scroll_speed = 0.15
var is_dragging = false
var touch_start_pos = Vector2.ZERO
var scroll_start_pos = 0.0

func _ready():
	if not self is Control: return

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_menu()

	if has_node("UI/Title"):
		get_node("UI/Title").text = "ВЫБОР МИССИИ"

	if SaveManager != null:
		_unlocked_levels = SaveManager.save_data.get("unlocked_levels", 1)

	_setup_grid()

	if scroll_container:
		scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
		target_scroll = scroll_container.scroll_vertical
		scroll_container.gui_input.connect(_on_scroll_input)

func _process(_delta):
	if scroll_container:
		var current = scroll_container.scroll_vertical
		if !OS.has_feature("mobile") and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			target_scroll = current
			return
		if is_dragging:
			return
		if abs(current - target_scroll) > 0.5:
			scroll_container.scroll_vertical = lerp(float(current), float(target_scroll), scroll_speed)
		else:
			scroll_container.scroll_vertical = int(target_scroll)

func _on_scroll_input(event):
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			target_scroll -= 180
			_clamp_scroll()
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			target_scroll += 180
			_clamp_scroll()
			accept_event()

	if event is InputEventScreenTouch:
		if event.pressed:
			is_dragging = true
			target_scroll = scroll_container.scroll_vertical
		else:
			is_dragging = false
			target_scroll = scroll_container.scroll_vertical
			_clamp_scroll()

	if event is InputEventScreenDrag:
		is_dragging = true
		target_scroll = scroll_container.scroll_vertical

func _clamp_scroll():
	if not scroll_container: return
	var max_scroll = max(0, scroll_container.get_v_scroll_bar().max_value - scroll_container.size.y)
	target_scroll = clamp(target_scroll, 0, max_scroll)

func _setup_grid():
	if grid == null: return
	for child in grid.get_children():
		child.queue_free()

	for i in range(1, _level_count + 1):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 120)
		btn.name = "Level_" + str(i)
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		btn.focus_mode = Control.FOCUS_NONE

		var major = ((i - 1) / 5) + 1
		var minor = ((i - 1) % 5) + 1
		btn.text = str(major) + "." + str(minor)
		btn.add_theme_font_size_override("font_size", 34)

		var is_locked = i > _unlocked_levels
		_apply_button_style(btn, i, is_locked)

		if !is_locked:
			btn.gui_input.connect(_on_level_btn_gui_input.bind(i))
		grid.add_child(btn)

func _apply_button_style(btn, i, is_locked):
	var is_passed = i < _unlocked_levels
	var is_boss = (i % 5 == 0)

	var style_normal = StyleBoxFlat.new()
	style_normal.set_corner_radius_all(15)
	style_normal.set_border_width_all(4)
	style_normal.border_width_bottom = 8

	if is_locked:
		style_normal.bg_color = Color(0.2, 0.2, 0.2, 0.8)
		style_normal.border_color = Color(0.1, 0.1, 0.1)
		btn.add_theme_color_override("font_disabled_color", Color(0.5, 0.5, 0.5))
		btn.disabled = true
	else:
		if is_boss:
			style_normal.bg_color = Color(0.35, 0.1, 0.1, 0.9) if is_passed else Color(0.7, 0.1, 0.1, 0.9)
			style_normal.border_color = Color(0.5, 0.2, 0.2, 0.8) if is_passed else Color(1, 0.2, 0.2, 1)
		else:
			style_normal.bg_color = Color(0.2, 0.6, 0.9, 0.9)
			style_normal.border_color = Color(1, 1, 1, 0.8)
			if is_passed: btn.add_theme_color_override("font_color", Color(0.2, 0.9, 0.2))

	var style_hover = style_normal.duplicate()
	style_hover.bg_color = style_hover.bg_color.lightened(0.1)

	var style_pressed = style_normal.duplicate()
	style_pressed.bg_color = style_pressed.bg_color.darkened(0.1)
	style_pressed.border_width_top = 8
	style_pressed.border_width_bottom = 2

	btn.add_theme_stylebox_override("normal", style_normal)
	btn.add_theme_stylebox_override("hover", style_hover)
	btn.add_theme_stylebox_override("pressed", style_pressed)
	btn.add_theme_stylebox_override("disabled", style_normal)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _on_level_btn_gui_input(event, level_num):
	if event is InputEventScreenTouch:
		if event.pressed:
			is_dragging = false
			touch_start_pos = event.position
			scroll_start_pos = scroll_container.scroll_vertical
		else:
			var drag_dist = event.position.distance_to(touch_start_pos)
			var scroll_dist = abs(scroll_container.scroll_vertical - scroll_start_pos)
			if drag_dist < 20 and scroll_dist < 10:
				_on_level_pressed(level_num)
			is_dragging = false
			target_scroll = scroll_container.scroll_vertical

	if event is InputEventScreenDrag:
		is_dragging = true
		target_scroll = scroll_container.scroll_vertical

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			touch_start_pos = event.position
			scroll_start_pos = scroll_container.scroll_vertical
		else:
			var drag_dist = event.position.distance_to(touch_start_pos)
			if drag_dist < 10:
				_on_level_pressed(level_num)

func _on_level_pressed(level_num: int):
	if SaveManager:
		SaveManager.current_level = level_num

	# Управление музыкой перед переходом
	if has_node("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		# Если уровень босса, можно заранее сменить музыку, либо LoadingScreen сам всё сделает
		if level_num % 5 != 0:
			am.stop()

	var path = "res://scenes/Levels/Level_" + str(level_num) + ".tscn"
	var final_path = ""

	if ResourceLoader.exists(path):
		final_path = path
	else:
		var alt_path = path.replace(".tscn", ".scn")
		if ResourceLoader.exists(alt_path):
			final_path = alt_path
		else:
			final_path = "res://scenes/Field.tscn"

	# ИСПОЛЬЗУЕМ АСИНХРОННУЮ ЗАГРУЗКУ
	if has_node("/root/LoadingManager"):
		get_node("/root/LoadingManager").load_level(final_path)
	else:
		get_tree().change_scene_to_file(final_path)

func _on_return_button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
