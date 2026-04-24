extends CanvasLayer

var _healthProgress: ProgressBar
var _healthLabel: Label
var _livesLabel: Label
var _moneyLabel: Label
var _basesLabel: Label
var _levelLabel: Label
var _warningLabel: Label
var _basesIcon: TextureRect
var _buffIcon: TextureRect
var _marker_overlay: Control
var _move_joy_c: MarginContainer
var _aim_joy_c: MarginContainer
var _aim: Node
var _ammo_anchor: Control

var _top_right: Control

var _total_enemy_bases: int = 0
var _destroyed_count: int = 0
var _player
var _ammo_buttons = {}
var _ammo_main_slot: Panel
var _ammo_option_slots: Array[Panel] = []
var _ammo_options_open: bool = false
var _ammo_options_tween: Tween
var _ammo_ui_mode: String = "classic"
var _ammo_popup_root: Control
var _ammo_hold_active: bool = false
var _ammo_hover_slot: int = -1
var _ammo_hold_touch_index: int = -1

# Параметры маркеров
var _level_time: float = 0.0
var _show_base_markers: bool = false
var _radar_active: bool = false
var _marker_setting_scale: float = 1.0
const BASE_MARKER_TIME = 90.0

# Параметры предупреждения об атаке
var _base_under_attack: bool = false
var _attack_warning_timer: float = 0.0
var _player_base_pos: Vector2 = Vector2.ZERO

var _marker_icons = {
	"boss": preload("res://assets/IngameAssets/Markers/free-icon-skull-11429788.png"),
	"enemy": preload("res://assets/IngameAssets/Markers/free-icon-army-tank-8511648.png"),
	"base": preload("res://assets/backround/PNG/Props/Platform.png"),
	"warning": preload("res://assets/IngameAssets/Markers/free-icon-broken-shield-4046202.png")
}

const AMMO_BTN_SIZE = 120
const AMMO_MAIN_BTN_SIZE = 116
const AMMO_DEFAULT_LOADOUT = [2, 0, 1]
const AMMO_UI_CLASSIC = "classic"
const AMMO_UI_POPUP = "popup"
const AMMO_POPUP_OFFSETS = [Vector2(-240, -170), Vector2(-300, 0), Vector2(-240, 170)]

func _ready():
	add_to_group("hud")
	
	_healthProgress = find_child("HealthProgress", true)
	_healthLabel = find_child("HealthLabel", true)
	_livesLabel = find_child("LivesLabel", true)
	_moneyLabel = find_child("MoneyLabel", true)
	_levelLabel = find_child("LevelLabel", true)
	_top_right = find_child("TopRight", true)

	_move_joy_c = find_child("MoveJoystickContainer", true)
	_aim_joy_c = find_child("AimJoystickContainer", true)
	_aim = find_child("Aim", true)
	_ammo_anchor = find_child("AmmoAnchor", true)

	if _move_joy_c: _move_joy_c.modulate.a = 0.4
	if _aim_joy_c: _aim_joy_c.modulate.a = 0.4
	if _top_right: _top_right.modulate.a = 0.5

	_setup_bases_label()
	_setup_buff_icon()
	_setup_marker_overlay()
	_setup_warning_label()

	var pause_btn = get_node_or_null("PauseButton")
	if not pause_btn: pause_btn = find_child("PauseButton", true)

	if pause_btn:
		pause_btn.pressed.connect(_on_pause_pressed)
		pause_btn.modulate.a = 0.5

	get_viewport().size_changed.connect(_on_viewport_size_changed)

	await get_tree().process_frame
	_update_level_display()
	_start_level_label_fade()
	call_deferred("_find_player_and_connect")

func activate_radar():
	_radar_active = true
	_show_base_markers = true

func _on_viewport_size_changed():
	if _ammo_buttons.size() > 0:
		_update_ammo_positions()

func _update_ammo_positions():
	if !_ammo_anchor or !_aim_joy_c: return

	# Используем контейнер джойстика для точного определения центра (он Control)
	var joy_center_global = _aim_joy_c.global_position + (_aim_joy_c.size / 2)
	var relative_joy = _ammo_anchor.get_global_transform().affine_inverse() * joy_center_global

	var center_angle = -PI / 2
	var spread = 0.63
	var angles = [center_angle - spread, center_angle, center_angle + spread]
	var radius = 210.0

	var children = _ammo_anchor.get_children()
	var btn_idx = 0
	for child in children:
		if child is TouchScreenButton:
			if btn_idx < angles.size():
				var offset = Vector2(cos(angles[btn_idx]), sin(angles[btn_idx])) * radius
				child.position = relative_joy + offset
				btn_idx += 1

func _start_level_label_fade():
	if _levelLabel:
		get_tree().create_timer(6.0).timeout.connect(func():
			var tween = create_tween()
			tween.tween_property(_levelLabel, "modulate:a", 0.0, 1.5)
			tween.finished.connect(func(): _levelLabel.visible = false)
		)

func _on_pause_pressed():
	var scene = get_tree().current_scene
	if scene and scene.has_method("toggle_pause"):
		scene.toggle_pause()
	elif scene and scene.has_method("_on_TouchScreenButton_pressed"):
		scene._on_TouchScreenButton_pressed()

func _setup_ammo_selection():
	if !_ammo_anchor or !_aim_joy_c: return
	for c in _ammo_anchor.get_children(): c.queue_free()
	_ammo_buttons.clear()

	var loadout = AMMO_DEFAULT_LOADOUT
	if _player != null and is_instance_valid(_player) and _player.has_method("get_ammo_loadout"):
		loadout = _player.get_ammo_loadout()

func _on_settings_changed_hud():
	_apply_lefty_joystick_layout()
	_load_marker_settings()
	_setup_ammo_selection()

	var center_angle = -PI / 2
	var spread = 0.63
	var angles = [center_angle - spread, center_angle, center_angle + spread]
	var radius = 210.0

	var mask_size = 128
	var circle_img = Image.create(mask_size, mask_size, false, Image.FORMAT_RGBA8)
	for y in range(mask_size):
		for x in range(mask_size):
			if Vector2(x - mask_size/2, y - mask_size/2).length() < mask_size/2:
				circle_img.set_pixel(x, y, Color.WHITE)
	var circle_tex = ImageTexture.create_from_image(circle_img)

	for i in range(3):
		var touch_btn = TouchScreenButton.new()
		var offset = Vector2(cos(angles[i]), sin(angles[i])) * radius
		touch_btn.position = relative_joy + offset

		var slot = Panel.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.custom_minimum_size = Vector2(AMMO_BTN_SIZE, AMMO_BTN_SIZE)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.3); style.set_corner_radius_all(40); style.border_color = Color(0.8, 0.8, 0.8, 0.5); style.set_border_width_all(2)
		slot.add_theme_stylebox_override("panel", style)
		slot.position = -Vector2(AMMO_BTN_SIZE/2, AMMO_BTN_SIZE/2)
		touch_btn.add_child(slot)

		var icon = TextureRect.new()
		var ammo_id = loadout[i] if i < loadout.size() else AMMO_DEFAULT_LOADOUT[i]
		icon.texture = load(_ammo_icon_path(ammo_id))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); icon.offset_left = 12; icon.offset_top = 12; icon.offset_right = -12; icon.offset_bottom = -12
		icon.pivot_offset = Vector2((AMMO_BTN_SIZE-24)/2, (AMMO_BTN_SIZE-24)/2)
		icon.rotation_degrees = 0
		slot.add_child(icon)

		var cooldown = TextureProgressBar.new()
		cooldown.name = "Cooldown"
		cooldown.fill_mode = TextureProgressBar.FILL_CLOCKWISE
		cooldown.texture_progress = circle_tex
		cooldown.nine_patch_stretch = true
		cooldown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		cooldown.tint_progress = Color(0, 0, 0, 0.6)
		cooldown.visible = false
		cooldown.step = 0.01
		slot.add_child(cooldown)

		touch_btn.shape = CircleShape2D.new(); touch_btn.shape.radius = AMMO_HITBOX_SIZE/2
		touch_btn.pressed.connect(func(): if _player: _player._on_ammo_selected(i))
		_ammo_anchor.add_child(touch_btn)
		_ammo_buttons[i] = slot

	if _player:
		_on_ammo_changed(_player.get("_current_ammo_slot"))

func _ammo_icon_path(ammo_id: int) -> String:
	match ammo_id:
		0: return "res://assets/future_tanks/PNG/Effects/Plasma.png"
		1: return "res://assets/future_tanks/PNG/Effects/Medium_Shell.png"
		2: return "res://assets/future_tanks/PNG/Effects/Light_Shell.png"
		3: return "res://assets/future_tanks/PNG/Effects/Heavy_Shell.png"
		4: return "res://assets/future_tanks/PNG/Effects/Sniper_Shell.png"
		5: return "res://assets/future_tanks/PNG/Effects/Laser.png"
		_: return "res://assets/future_tanks/PNG/Effects/Plasma.png"

func _process(delta):
	_update_ammo_cooldowns()
	_level_time += delta
	# Если радар активен, маркеры баз должны быть всегда
	if _radar_active: _show_base_markers = true
	elif _level_time >= BASE_MARKER_TIME: _show_base_markers = true

	if _base_under_attack:
		_attack_warning_timer -= delta
		if _attack_warning_timer <= 0:
			_base_under_attack = false
			if _warningLabel: _warningLabel.visible = false
	if _marker_overlay: _marker_overlay.queue_redraw()

func _update_ammo_cooldowns():
	if _player == null or not is_instance_valid(_player): return
	var timer = _player.get("_shoot_timer")
	for i in range(3):
		if not _ammo_buttons.has(i): continue
		var slot = _ammo_buttons[i]
		var cd = slot.get_node("Cooldown") as TextureProgressBar
		if timer and not timer.is_stopped() and i == _player.get("_current_ammo_slot"):
			cd.visible = true
			cd.value = (timer.time_left / timer.wait_time) * 100
		else: cd.visible = false

func _on_ammo_changed(type):
	for i in _ammo_buttons:
		var slot = _ammo_buttons[i]
		slot.modulate.a = 1.0 if i == type else 0.5
		var style = slot.get_theme_stylebox("panel").duplicate()
		style.border_color = Color(1, 0.8, 0) if i == type else Color(0.8, 0.8, 0.8, 0.5)
		slot.add_theme_stylebox_override("panel", style)

func _setup_buff_icon():
	if has_node("BuffMarginContainer"): return
	var buff_margin = MarginContainer.new()
	buff_margin.name = "BuffMarginContainer"
	add_child(buff_margin)
	buff_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	buff_margin.add_theme_constant_override("margin_left", 125); buff_margin.add_theme_constant_override("margin_top", 15)
	_buffIcon = TextureRect.new()
	_buffIcon.texture = load("res://assets/IngameAssets/HUD/free-icon-arrows-14035529.png")
	_buffIcon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; _buffIcon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_buffIcon.custom_minimum_size = Vector2(64, 64); _buffIcon.modulate = Color(0.0, 1.0, 0.0, 0.8); _buffIcon.visible = false
	buff_margin.add_child(_buffIcon)

func set_buff_icon_visible(show_buff: bool):
	if _buffIcon: _buffIcon.visible = show_buff

func _setup_warning_label():
	var top_center = find_child("TopCenter", true)
	if !top_center: return
	top_center.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	var vbox = VBoxContainer.new()
	vbox.name = "CenterLabelsVBox"
	vbox.custom_minimum_size = Vector2(800, 0)
	top_center.add_child(vbox)
	if _levelLabel and _levelLabel.get_parent():
		_levelLabel.get_parent().remove_child(_levelLabel)
		vbox.add_child(_levelLabel)
		_levelLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warningLabel = Label.new()
	_warningLabel.name = "WarningLabel"
	_warningLabel.text = "ШТАБ АТАКУЮТ!"
	_warningLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warningLabel.add_theme_font_size_override("font_size", 42)
	_warningLabel.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	_warningLabel.add_theme_color_override("font_outline_color", Color.BLACK)
	_warningLabel.add_theme_constant_override("outline_size", 12)
	vbox.add_child(_warningLabel)
	_warningLabel.visible = false

func trigger_base_attack_warning(base_pos: Vector2):
	_base_under_attack = true; _player_base_pos = base_pos; _attack_warning_timer = 4.0
	if _warningLabel: _warningLabel.visible = true

func _setup_marker_overlay():
	_marker_overlay = Control.new()
	_marker_overlay.name = "MarkerOverlay"
	_marker_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marker_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker_overlay.draw.connect(_on_marker_overlay_draw)
	add_child(_marker_overlay)

func _setup_bases_label():
	var stats_container = find_child("Stats", true)
	if !stats_container: return
	var bases_row = HBoxContainer.new(); bases_row.alignment = BoxContainer.ALIGNMENT_END; stats_container.add_child(bases_row)
	_basesIcon = TextureRect.new(); _basesIcon.texture = load("res://assets/backround/PNG/Props/Platform.png"); _basesIcon.custom_minimum_size = Vector2(40, 40); _basesIcon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; _basesIcon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED; _basesIcon.modulate = Color(1.0, 0.3, 0.3, 0.8); bases_row.add_child(_basesIcon)
	_basesLabel = Label.new(); _basesLabel.add_theme_font_size_override("font_size", 32); bases_row.add_child(_basesLabel); call_deferred("_initialize_bases_count")

func _initialize_bases_count():
	await get_tree().process_frame
	_total_enemy_bases = get_tree().get_nodes_in_group("bases").filter(func(b): return b.get("type_base") == 1).size(); _destroyed_count = 0; _update_bases_display()

func update_bases_count(): _destroyed_count += 1; _update_bases_display()

func _update_bases_display():
	if _basesLabel: _basesLabel.text = str(min(_destroyed_count, _total_enemy_bases)) + "/" + str(_total_enemy_bases)

func _update_level_display():
	if !_levelLabel: return
	var lvl = SaveManager.current_level if SaveManager else 1
	_levelLabel.text = "МИССИЯ " + str(((lvl-1)/5)+1) + "." + str(((lvl-1)%5)+1)

	if lvl % 5 == 0:
		_levelLabel.add_theme_color_override("font_color", Color(1, 0.2, 0.2)) # Красный
	else:
		_levelLabel.add_theme_color_override("font_color", Color(1, 1, 0)) # Желтый

func _find_player_and_connect():
	_player = get_tree().get_first_node_in_group("players")
	if _player:
		_setup_ammo_selection()
		_update_level_display() # Принудительное обновление при подключении игрока
		if not _player.health_changed.is_connected(_on_health_changed): _player.health_changed.connect(_on_health_changed)
		if not _player.lives_changed.is_connected(_on_lives_changed): _player.lives_changed.connect(_on_lives_changed)
		if not _player.money_changed.is_connected(_on_money_changed): _player.money_changed.connect(_on_money_changed)
		if _player.has_signal("ammo_changed") and not _player.ammo_changed.is_connected(_on_ammo_changed):
			_player.ammo_changed.connect(_on_ammo_changed)
		_on_health_changed(_player.get_current_health(), _player.get_max_health())
		_on_lives_changed(_player.get_lives())
		_on_money_changed(_player.get_money())
	else:
		get_tree().create_timer(0.5).timeout.connect(_find_player_and_connect)

func _on_health_changed(curr, m):
	if _healthProgress:
		_healthProgress.max_value = m; _healthProgress.value = curr
		_healthLabel.text = str(max(0,curr)) + "/" + str(m); _update_health_bar_color(curr, m)
		highlight_health()

func _update_health_bar_color(curr, m):
	var ratio = float(curr) / float(m); var style = StyleBoxFlat.new(); style.set_corner_radius_all(5)
	if ratio > 0.6: style.bg_color = Color(0.2, 0.8, 0.2)
	elif ratio > 0.3: style.bg_color = Color(0.9, 0.8, 0.1)
	else: style.bg_color = Color(0.8, 0.1, 0.1)
	_healthProgress.add_theme_stylebox_override("fill", style)

func _on_lives_changed(l): if _livesLabel: _livesLabel.text = "Жизни: " + str(l)
func _on_money_changed(m): if _moneyLabel: _moneyLabel.text = str(m)

func _setup_ammo_selection():
	_clear_ammo_selection()
	_ammo_ui_mode = _get_ammo_ui_mode()
	if _ammo_ui_mode == AMMO_UI_POPUP:
		_setup_popup_ammo_selection()
	else:
		_setup_classic_ammo_selection()

	if _player != null and is_instance_valid(_player):
		_on_ammo_changed(_player.get("_current_ammo_slot"))

func _clear_ammo_selection():
	if has_node("AmmoPanelContainer"):
		get_node("AmmoPanelContainer").queue_free()
	if has_node("AmmoPopupContainer"):
		get_node("AmmoPopupContainer").queue_free()
	_ammo_buttons.clear()
	_ammo_option_slots.clear()
	_ammo_main_slot = null
	_ammo_popup_root = null
	_ammo_hold_active = false
	_ammo_hover_slot = -1
	_ammo_hold_touch_index = -1
	_ammo_options_open = false
	if _ammo_options_tween:
		_ammo_options_tween.kill()
		_ammo_options_tween = null

func _get_ammo_ui_mode() -> String:
	if SaveManager == null:
		return AMMO_UI_CLASSIC
	var mode = str(SaveManager.get_setting("game", "ammo_ui_mode", AMMO_UI_CLASSIC))
	return mode if mode == AMMO_UI_POPUP else AMMO_UI_CLASSIC

func _setup_classic_ammo_selection():
	var ammo_container = CenterContainer.new()
	ammo_container.name = "AmmoPanelContainer"
	add_child(ammo_container)
	ammo_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ammo_container.offset_top = -180; ammo_container.offset_bottom = -30
	ammo_container.anchor_left = 0.5; ammo_container.anchor_right = 0.5
	ammo_container.offset_left = -500; ammo_container.offset_right = 500

	var ammo_panel = HBoxContainer.new()
	ammo_panel.name = "AmmoPanel"
	ammo_panel.add_theme_constant_override("separation", 25)
	ammo_container.add_child(ammo_panel)

	var loadout = _get_current_ammo_loadout()
	for i in range(3):
		var ammo_id = loadout[i] if i < loadout.size() else AMMO_DEFAULT_LOADOUT[i]
		var slot = _create_ammo_slot(ammo_id, i, AMMO_BTN_SIZE, true)
		ammo_panel.add_child(slot)
		_ammo_buttons[i] = slot

func _setup_popup_ammo_selection():
	var popup_root = Control.new()
	popup_root.name = "AmmoPopupContainer"
	popup_root.custom_minimum_size = Vector2(AMMO_MAIN_BTN_SIZE, AMMO_MAIN_BTN_SIZE)
	add_child(popup_root)
	_ammo_popup_root = popup_root
	popup_root.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	popup_root.offset_left = -250
	popup_root.offset_top = -430
	popup_root.offset_right = -130
	popup_root.offset_bottom = -310

	var loadout = _get_current_ammo_loadout()
	var selected_slot := 0
	if _player != null and is_instance_valid(_player):
		selected_slot = clampi(int(_player.get("_current_ammo_slot")), 0, 2)
	var selected_ammo = loadout[selected_slot] if selected_slot < loadout.size() else AMMO_DEFAULT_LOADOUT[selected_slot]

	_ammo_main_slot = _create_ammo_slot(selected_ammo, -1, AMMO_MAIN_BTN_SIZE, false)
	_ammo_main_slot.position = Vector2.ZERO
	popup_root.add_child(_ammo_main_slot)
	var main_btn = TouchScreenButton.new()
	main_btn.shape = RectangleShape2D.new()
	main_btn.shape.size = Vector2(AMMO_MAIN_BTN_SIZE, AMMO_MAIN_BTN_SIZE)
	main_btn.position = Vector2(AMMO_MAIN_BTN_SIZE / 2.0, AMMO_MAIN_BTN_SIZE / 2.0)
	_ammo_main_slot.add_child(main_btn)

	for i in range(3):
		var ammo_id = loadout[i] if i < loadout.size() else AMMO_DEFAULT_LOADOUT[i]
		var opt = _create_ammo_slot(ammo_id, i, AMMO_BTN_SIZE, false)
		opt.position = Vector2((AMMO_MAIN_BTN_SIZE - AMMO_BTN_SIZE) * 0.5, (AMMO_MAIN_BTN_SIZE - AMMO_BTN_SIZE) * 0.5)
		opt.modulate.a = 0.0
		opt.scale = Vector2(0.65, 0.65)
		opt.visible = false
		popup_root.add_child(opt)
		_ammo_option_slots.append(opt)
		_ammo_buttons[i] = opt

func _get_current_ammo_loadout() -> Array[int]:
	if _player != null and is_instance_valid(_player) and _player.has_method("get_ammo_loadout"):
		return _player.get_ammo_loadout()
	return [AMMO_DEFAULT_LOADOUT[0], AMMO_DEFAULT_LOADOUT[1], AMMO_DEFAULT_LOADOUT[2]]

func _create_ammo_slot(ammo_id: int, slot_idx: int, size: int, connect_select: bool) -> Panel:
	var slot = Panel.new()
	slot.custom_minimum_size = Vector2(size, size)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.1, 0.6)
	style.set_corner_radius_all(15)
	style.border_color = Color(0.4, 0.4, 0.4)
	style.set_border_width_all(3)
	slot.add_theme_stylebox_override("panel", style)

	var icon = TextureRect.new()
	icon.name = "Icon"
	icon.texture = load(_ammo_icon_path(ammo_id))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.offset_left = 18; icon.offset_top = 18; icon.offset_right = -18; icon.offset_bottom = -18
	slot.add_child(icon)

	var cooldown = Panel.new()
	var cd_style = StyleBoxFlat.new()
	cd_style.bg_color = Color(0, 0, 0, 0.7)
	cd_style.set_corner_radius_all(15)
	cooldown.add_theme_stylebox_override("panel", cd_style)
	cooldown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cooldown.visible = false
	cooldown.name = "Cooldown"
	slot.add_child(cooldown)

	if connect_select:
		var touch_btn = TouchScreenButton.new()
		touch_btn.shape = RectangleShape2D.new()
		touch_btn.shape.size = Vector2(size, size)
		touch_btn.position = Vector2(size / 2.0, size / 2.0)
		touch_btn.pressed.connect(func():
			if _player:
				_player._on_ammo_selected(slot_idx)
			if _ammo_ui_mode == AMMO_UI_POPUP:
				_set_ammo_options_open(false)
		)
		slot.add_child(touch_btn)

	return slot

func _on_ammo_main_pressed():
	_ammo_hold_active = true
	_ammo_hold_touch_index = -1
	_ammo_hover_slot = -1
	_set_ammo_options_open(true)

func _on_ammo_main_released():
	_finish_ammo_hold_selection()

func _finish_ammo_hold_selection():
	if not _ammo_hold_active:
		return
	_ammo_hold_active = false
	_ammo_hold_touch_index = -1
	if _ammo_hover_slot >= 0 and _player != null and is_instance_valid(_player):
		_player._on_ammo_selected(_ammo_hover_slot)
	_ammo_hover_slot = -1
	_apply_popup_hover_visuals()
	_set_ammo_options_open(false)

func _update_popup_hover(screen_pos: Vector2):
	if not _ammo_hold_active or not _ammo_options_open:
		return
	var hovered := -1
	for i in range(_ammo_option_slots.size()):
		var rect = _ammo_option_slots[i].get_global_rect()
		if rect.has_point(screen_pos):
			hovered = i
			break
	if hovered != _ammo_hover_slot:
		_ammo_hover_slot = hovered
		_apply_popup_hover_visuals()

func _apply_popup_hover_visuals():
	if _ammo_ui_mode != AMMO_UI_POPUP:
		return
	if _player != null and is_instance_valid(_player):
		_on_ammo_changed(_player.get("_current_ammo_slot"))
	for i in _ammo_buttons:
		var slot = _ammo_buttons[i]
		var style = slot.get_theme_stylebox("panel").duplicate()
		if i == _ammo_hover_slot:
			style.border_color = Color(0.25, 1.0, 0.95)
			slot.modulate.a = 1.0
		slot.add_theme_stylebox_override("panel", style)

func _is_over_ammo_main_button(screen_pos: Vector2) -> bool:
	if _ammo_main_slot == null:
		return false
	return _ammo_main_slot.get_global_rect().has_point(screen_pos)

func _set_ammo_options_open(open: bool):
	if _ammo_ui_mode != AMMO_UI_POPUP:
		return
	if _ammo_options_tween:
		_ammo_options_tween.kill()
		_ammo_options_tween = null

	_ammo_options_open = open
	_ammo_options_tween = create_tween().set_parallel(true)

	for i in range(_ammo_option_slots.size()):
		var slot = _ammo_option_slots[i]
		var base_pos = Vector2((AMMO_MAIN_BTN_SIZE - AMMO_BTN_SIZE) * 0.5, (AMMO_MAIN_BTN_SIZE - AMMO_BTN_SIZE) * 0.5)
		if open:
			slot.visible = true
			_ammo_options_tween.tween_property(slot, "position", base_pos + AMMO_POPUP_OFFSETS[i], 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			_ammo_options_tween.tween_property(slot, "modulate:a", 1.0, 0.18)
			_ammo_options_tween.tween_property(slot, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_ammo_options_tween.tween_property(slot, "position", base_pos, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
			_ammo_options_tween.tween_property(slot, "modulate:a", 0.0, 0.14)
			_ammo_options_tween.tween_property(slot, "scale", Vector2(0.65, 0.65), 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)

	if not open:
		_ammo_options_tween.finished.connect(func():
			for slot in _ammo_option_slots:
				slot.visible = false
		)

func _ammo_icon_path(ammo_id: int) -> String:
	match ammo_id:
		0: return "res://assets/future_tanks/PNG/Effects/Plasma.png"
		1: return "res://assets/future_tanks/PNG/Effects/Medium_Shell.png"
		2: return "res://assets/future_tanks/PNG/Effects/Light_Shell.png"
		3: return "res://assets/future_tanks/PNG/Effects/Granade_Shell.png"
		4: return "res://assets/future_tanks/PNG/Effects/Heavy_Shell.png"
		5: return "res://assets/future_tanks/PNG/Effects/Laser.png"
		_: return "res://assets/future_tanks/PNG/Effects/Plasma.png"

func _process(delta):
	_update_ammo_cooldowns()
	_level_time += delta
	if !_radar_active and _level_time >= BASE_MARKER_TIME: _show_base_markers = true
	if _base_under_attack:
		_attack_warning_timer -= delta
		if _attack_warning_timer <= 0:
			_base_under_attack = false
			if _warningLabel: _warningLabel.visible = false
	if _marker_overlay: _marker_overlay.queue_redraw()

func _input(event):
	if _ammo_ui_mode != AMMO_UI_POPUP:
		return
	if event is InputEventScreenTouch:
		if event.pressed and _is_over_ammo_main_button(event.position):
			_on_ammo_main_pressed()
			_ammo_hold_touch_index = event.index
			_update_popup_hover(event.position)
		elif not event.pressed and _ammo_hold_active and (_ammo_hold_touch_index == -1 or event.index == _ammo_hold_touch_index):
			_finish_ammo_hold_selection()
	elif event is InputEventScreenDrag:
		if _ammo_hold_active and (_ammo_hold_touch_index == -1 or event.index == _ammo_hold_touch_index):
			_update_popup_hover(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and _is_over_ammo_main_button(event.position):
			_on_ammo_main_pressed()
			_update_popup_hover(event.position)
		elif not event.pressed and _ammo_hold_active:
			_finish_ammo_hold_selection()
	elif event is InputEventMouseMotion and _ammo_hold_active and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_update_popup_hover(event.position)

func _update_ammo_cooldowns():
	if _player == null or not is_instance_valid(_player): return
	var timer = _player.get("_shoot_timer")
	if _ammo_ui_mode == AMMO_UI_POPUP and _ammo_main_slot != null:
		var main_cd = _ammo_main_slot.get_node("Cooldown")
		if timer and not timer.is_stopped():
			main_cd.visible = true
			var main_ratio = timer.time_left / timer.wait_time
			main_cd.anchor_top = 1.0 - main_ratio
			main_cd.anchor_bottom = 1.0
			main_cd.offset_top = 0
			main_cd.offset_bottom = 0
		else:
			main_cd.visible = false
		return

	for i in range(3):
		if not _ammo_buttons.has(i): continue
		var slot = _ammo_buttons[i]
		var cd = slot.get_node("Cooldown")
		if timer and not timer.is_stopped() and i == _player.get("_current_ammo_slot"):
			cd.visible = true; var ratio = timer.time_left / timer.wait_time
			cd.anchor_top = 1.0 - ratio; cd.anchor_bottom = 1.0; cd.offset_top = 0; cd.offset_bottom = 0
		else: cd.visible = false

func _on_ammo_changed(type):
	type = int(type)
	var loadout = _get_current_ammo_loadout()
	if _ammo_ui_mode == AMMO_UI_POPUP and _ammo_main_slot != null:
		var selected_ammo = loadout[type] if type >= 0 and type < loadout.size() else AMMO_DEFAULT_LOADOUT[0]
		var main_icon = _ammo_main_slot.get_node_or_null("Icon") as TextureRect
		if main_icon != null:
			main_icon.texture = load(_ammo_icon_path(selected_ammo))
	for i in _ammo_buttons:
		var slot = _ammo_buttons[i]
		var style = slot.get_theme_stylebox("panel").duplicate()
		if i == type: style.border_color = Color(1, 0.8, 0.2); slot.modulate.a = 1.0
		else: style.border_color = Color(0.4, 0.4, 0.4); slot.modulate.a = 0.6
		slot.add_theme_stylebox_override("panel", style)

func _on_marker_overlay_draw():
	if _player == null or not is_instance_valid(_player): return
	var cam_transform = _player.get_viewport().get_canvas_transform(); var cam_pos = cam_transform.affine_inverse().get_origin(); var cam_scale = cam_transform.get_scale(); var view_size = get_viewport().get_visible_rect().size / cam_scale; var screen_rect = Rect2(cam_pos, view_size)
	if _base_under_attack:
		_draw_marker_for(_player_base_pos, Color.GREEN, _marker_icons.warning, screen_rect, true, 1.2)
	var enemy_bases = get_tree().get_nodes_in_group("bases").filter(func(b): return b.get("type_base") == 1)
	if enemy_bases.size() == 0:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy.get("_type_enemy") != 5: _draw_marker_for(enemy.global_position, Color(0, 0.5, 1, 0.7), _marker_icons.enemy, screen_rect, false, 0.9)
	if _show_base_markers:
		for base in get_tree().get_nodes_in_group("bases"):
			if is_instance_valid(base) and base.get("type_base") == 1: _draw_marker_for(base.global_position, Color(1, 1, 0, 0.7), _marker_icons.base, screen_rect, false, 0.9)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.get("_type_enemy") == 5: _draw_marker_for(enemy.global_position, Color("#f34235"), _marker_icons.boss, screen_rect, false, 1.3)

func _draw_marker_for(target_pos: Vector2, color: Color, icon: Texture2D, screen_rect: Rect2, pulse: bool, max_scale: float):
	if screen_rect.has_point(target_pos): return
	var center = screen_rect.get_center(); var dir = (target_pos - center).normalized(); var dist = center.distance_to(target_pos); var marker_pos = _get_intersect_pos(center, dir, screen_rect); var margin = 80.0
	marker_pos.x = clamp(marker_pos.x, screen_rect.position.x + margin, screen_rect.end.x - margin); marker_pos.y = clamp(marker_pos.y, screen_rect.position.y + margin, screen_rect.end.y - margin)
	var draw_pos = _player.get_viewport().get_canvas_transform() * marker_pos;
	var base_scale = clamp(remap(dist, 800, 3000, max_scale, 0.4), 0.4, max_scale)
	var scale_factor = base_scale * (SaveManager.get_setting("game", "marker_scale", 1.0) if SaveManager else 1.0)
	if pulse: scale_factor *= 1.0 + (sin(Time.get_ticks_msec() * 0.005) * 0.15)

	_marker_overlay.draw_circle(draw_pos, 35 * scale_factor, Color(0, 0, 0, 0.4))
	_marker_overlay.draw_circle(draw_pos, 30 * scale_factor, Color(color.r, color.g, color.b, 0.7))
	if icon:
		var icon_size = Vector2(44, 44) * scale_factor
		_marker_overlay.draw_texture_rect(icon, Rect2(draw_pos - icon_size/2, icon_size), false, Color(1, 1, 1, 0.9))

	var tip_dist = 55 * scale_factor
	var base_dist = 32 * scale_factor
	var pts = PackedVector2Array([
		draw_pos + dir * tip_dist,
		draw_pos + dir.rotated(0.4) * base_dist,
		draw_pos + dir.rotated(-0.4) * base_dist
	])
	_marker_overlay.draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.7))

func _get_intersect_pos(center: Vector2, dir: Vector2, rect: Rect2) -> Vector2:
	var t_max = Vector2.ZERO
	if dir.x > 0: t_max.x = (rect.end.x - center.x) / dir.x
	elif dir.x < 0: t_max.x = (rect.position.x - center.x) / dir.x
	else: t_max.x = 1e10
	if dir.y > 0: t_max.y = (rect.end.y - center.y) / dir.y
	elif dir.y < 0: t_max.y = (rect.position.y - center.y) / dir.y
	else: t_max.y = 1e10
	return center + dir * min(t_max.x, t_max.y)
