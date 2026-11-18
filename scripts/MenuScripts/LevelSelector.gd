extends Control

@onready var page_viewport: Control = $UI/PageViewport
@onready var page_track: Control = $UI/PageViewport/PageTrack
@onready var previous_button: Button = $UI/PreviousPage
@onready var next_button: Button = $UI/NextPage
@onready var page_indicator: Label = $UI/PageIndicator

const LEVELS_PER_PAGE := 15
const PAGE_DURATION := 0.3
const DRAG_SLOP := 14.0
const TAP_SLOP := 20.0

var _level_count = 25
var _unlocked_levels = 1

var _pages: Array[GridContainer] = []
var _current_page := 0
var _page_tween: Tween
var _pointer_id := -2
var _touch_start := Vector2.ZERO
var _track_start := 0.0
var _max_drag_distance := 0.0
var _dragging := false
var _pressed_level := 0

func _ready():
	if not self is Control: return

	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_menu()

	if has_node("UI/Title"):
		get_node("UI/Title").text = "ВЫБОР МИССИИ"

	if SaveManager != null:
		_unlocked_levels = SaveManager.save_data.get("unlocked_levels", 1)

	_setup_pages()
	_style_page_arrow(previous_button)
	_style_page_arrow(next_button)
	previous_button.pressed.connect(_change_page.bind(-1))
	next_button.pressed.connect(_change_page.bind(1))
	page_viewport.resized.connect(_layout_pages)
	_layout_pages()

func _setup_pages():
	for page_index in range(ceili(float(_level_count) / LEVELS_PER_PAGE)):
		var page := GridContainer.new()
		page.name = "Page_" + str(page_index + 1)
		page.columns = 5
		page.add_theme_constant_override("h_separation", 20)
		page.add_theme_constant_override("v_separation", 20)
		page.mouse_filter = Control.MOUSE_FILTER_PASS
		page_track.add_child(page)
		_pages.append(page)
	for i in range(1, _level_count + 1):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(120, 120)
		btn.name = "Level_" + str(i)
		btn.mouse_filter = Control.MOUSE_FILTER_PASS
		btn.focus_mode = Control.FOCUS_NONE

		var major = int((i - 1) / 5) + 1
		var minor = ((i - 1) % 5) + 1
		btn.text = str(major) + "." + str(minor)
		btn.add_theme_font_size_override("font_size", 34)

		var is_locked = i > _unlocked_levels
		_apply_button_style(btn, i, is_locked)

		_pages[int((i - 1) / LEVELS_PER_PAGE)].add_child(btn)

func _layout_pages():
	if _page_tween:
		_page_tween.kill()
	_pointer_id = -2
	_dragging = false
	page_track.size = Vector2(page_viewport.size.x * _pages.size(), page_viewport.size.y)
	for index in range(_pages.size()):
		var page := _pages[index]
		var rows := ceili(float(page.get_child_count()) / 5.0)
		page.size = Vector2(680, rows * 120 + (rows - 1) * 20)
		page.position = Vector2(index * page_viewport.size.x + (page_viewport.size.x - page.size.x) * 0.5,
			(page_viewport.size.y - page.size.y) * 0.5)
	page_track.position.x = -_current_page * page_viewport.size.x
	_update_page_controls()

func _style_page_arrow(button: Button):
	# Та же оливковая палитра, что у кнопки «В меню».
	var menu_button: Button = $UI/ReturnButton
	for state in ["normal", "hover", "pressed"]:
		button.add_theme_stylebox_override(state, menu_button.get_theme_stylebox(state).duplicate())
	var disabled_style := menu_button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
	disabled_style.bg_color = Color(0.12, 0.15, 0.12, 0.65)
	disabled_style.border_color = Color(0.24, 0.28, 0.22, 0.65)
	button.add_theme_stylebox_override("disabled", disabled_style)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.add_theme_color_override("font_color", Color(0.74, 0.82, 0.71))
	button.add_theme_color_override("font_hover_color", Color(0.88, 0.94, 0.84))
	button.add_theme_color_override("font_pressed_color", Color(0.88, 0.94, 0.84))
	button.add_theme_color_override("font_disabled_color", Color(0.37, 0.42, 0.34))

func _update_page_controls():
	var busy := _page_tween != null and _page_tween.is_running()
	previous_button.disabled = busy or _current_page == 0
	next_button.disabled = busy or _current_page == _pages.size() - 1
	var dots := PackedStringArray()
	for index in range(_pages.size()):
		dots.append("●" if index == _current_page else "○")
	page_indicator.text = "   ".join(dots)

func _change_page(direction: int):
	if _pointer_id != -2 or (_page_tween and _page_tween.is_running()):
		return
	_animate_to_page(_current_page + direction)

func _animate_to_page(page_index: int):
	_current_page = clampi(page_index, 0, _pages.size() - 1)
	if _page_tween:
		_page_tween.kill()
	_page_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_page_tween.tween_property(page_track, "position:x", -_current_page * page_viewport.size.x, PAGE_DURATION)
	_update_page_controls()
	_page_tween.finished.connect(_update_page_controls)

func _input(event: InputEvent):
	# Не обрабатываем второй раз события, сгенерированные эмуляцией мыши/тача.
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_begin_gesture(event.position, event.index)
		elif _pointer_id == event.index:
			_end_gesture(event.position, event.canceled)
	elif event is InputEventScreenDrag and _pointer_id == event.index:
		_drag_gesture(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_gesture(event.position, -1)
		elif _pointer_id == -1:
			_end_gesture(event.position, event.canceled)
	elif event is InputEventMouseMotion and _pointer_id == -1:
		_drag_gesture(event.position)

func _begin_gesture(point: Vector2, pointer: int):
	if _pointer_id != -2 or not page_viewport.get_global_rect().has_point(point):
		return
	if _page_tween and _page_tween.is_running():
		return
	_pointer_id = pointer
	_touch_start = point
	_track_start = page_track.position.x
	_max_drag_distance = 0.0
	_dragging = false
	_pressed_level = 0
	for button in _pages[_current_page].get_children():
		if not button.disabled and button.get_global_rect().has_point(point):
			_pressed_level = int(str(button.name).trim_prefix("Level_"))
			break

func _drag_gesture(point: Vector2):
	var offset := point - _touch_start
	_max_drag_distance = maxf(_max_drag_distance, offset.length())
	if not _dragging and absf(offset.x) >= DRAG_SLOP and absf(offset.x) > absf(offset.y):
		_dragging = true
	if _dragging:
		var desired_x := _track_start + offset.x
		var last_page_x := -(_pages.size() - 1) * page_viewport.size.x
		# Небольшое сопротивление у краёв, затем возврат той же анимацией.
		if desired_x > 0.0:
			desired_x *= 0.2
		elif desired_x < last_page_x:
			desired_x = last_page_x + (desired_x - last_page_x) * 0.2
		page_track.position.x = desired_x

func _end_gesture(point: Vector2, canceled: bool = false):
	_drag_gesture(point)
	_pointer_id = -2
	if _dragging:
		var distance := point.x - _touch_start.x
		var direction := 0
		if not canceled and absf(distance) >= minf(100.0, page_viewport.size.x * 0.15):
			direction = -1 if distance > 0 else 1
		_dragging = false
		_animate_to_page(_current_page + direction)
	elif not canceled and _max_drag_distance < TAP_SLOP and _pressed_level > 0:
		_on_level_pressed(_pressed_level)
	_pressed_level = 0

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

func _on_Return_Button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
