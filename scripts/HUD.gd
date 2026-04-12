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

var _total_enemy_bases: int = 0
var _destroyed_count: int = 0
var _player
var _ammo_buttons = {}

# Параметры маркеров
var _level_time: float = 0.0
var _show_base_markers: bool = false
const BASE_MARKER_TIME = 90.0

# Параметры предупреждения об атаке
var _base_under_attack: bool = false
var _attack_warning_timer: float = 0.0
var _player_base_pos: Vector2 = Vector2.ZERO

var _marker_icons = {
	"boss": preload("res://assets/free-icon-skull-11429788.png"),
	"enemy": preload("res://assets/free-icon-army-tank-8511648.png"),
	"base": preload("res://assets/backround/PNG/Props/Platform.png"),
	"warning": preload("res://assets/free-icon-broken-shield-4046202.png")
}

const AMMO_BTN_SIZE = 120

func _ready():
	add_to_group("hud")
	
	_healthProgress = find_child("HealthProgress", true)
	_healthLabel = find_child("HealthLabel", true)
	_livesLabel = find_child("LivesLabel", true)
	_moneyLabel = find_child("MoneyLabel", true)
	_levelLabel = find_child("LevelLabel", true)

	_setup_bases_label()
	_setup_buff_icon()
	_setup_marker_overlay()
	_setup_warning_label()
	_setup_ammo_selection()
	_update_level_display()

	if _healthProgress:
		_setup_progress_bar_style()
		_healthProgress.value = 100

	_move_joy_c = find_child("MoveJoystickContainer", true, false) as MarginContainer
	_aim_joy_c = find_child("AimJoystickContainer", true, false) as MarginContainer
	if SaveManager != null and not SaveManager.settings_changed.is_connected(_on_settings_changed_hud):
		SaveManager.settings_changed.connect(_on_settings_changed_hud)
	call_deferred("_apply_lefty_joystick_layout")

	call_deferred("_find_player_and_connect")

func _setup_warning_label():
	var center_top = find_child("TopCenter", true)
	if !center_top or !_levelLabel: return

	# Создаем VBoxContainer для предотвращения наложения текстов
	var vbox = VBoxContainer.new()
	vbox.name = "HeaderVBox"
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	vbox.add_theme_constant_override("separation", 10)
	center_top.add_child(vbox)

	# Перемещаем LevelLabel в новый контейнер
	if _levelLabel.get_parent():
		_levelLabel.get_parent().remove_child(_levelLabel)
	vbox.add_child(_levelLabel)

	_warningLabel = Label.new()
	_warningLabel.name = "WarningLabel"
	_warningLabel.text = "Штаб атакуют!"
	_warningLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warningLabel.add_theme_font_size_override("font_size", 32)
	_warningLabel.add_theme_color_override("font_color", Color("#f34235"))
	_warningLabel.add_theme_color_override("font_outline_color", Color.BLACK)
	_warningLabel.add_theme_constant_override("outline_size", 8)
	_warningLabel.visible = false

	vbox.add_child(_warningLabel)

func trigger_base_attack_warning(base_pos: Vector2):
	_base_under_attack = true
	_player_base_pos = base_pos
	_attack_warning_timer = 3.0
	if _warningLabel: _warningLabel.visible = true

func _setup_marker_overlay():
	_marker_overlay = Control.new()
	_marker_overlay.name = "MarkerOverlay"
	_marker_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_marker_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker_overlay.draw.connect(_on_marker_overlay_draw)
	add_child(_marker_overlay)

func _setup_buff_icon():
	var buff_margin = MarginContainer.new()
	buff_margin.name = "BuffMarginContainer"
	add_child(buff_margin)
	buff_margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	buff_margin.add_theme_constant_override("margin_left", 125)
	buff_margin.add_theme_constant_override("margin_top", 15)

	_buffIcon = TextureRect.new()
	_buffIcon.texture = load("res://assets/free-icon-arrows-14035529.png")
	_buffIcon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_buffIcon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_buffIcon.custom_minimum_size = Vector2(64, 64)
	_buffIcon.modulate = Color(0.0, 1.0, 0.0, 0.8)
	_buffIcon.visible = false
	_buffIcon.name = "BuffIcon"
	buff_margin.add_child(_buffIcon)

func set_buff_icon_visible(is_visible: bool):
	if _buffIcon: _buffIcon.visible = is_visible

func _on_settings_changed_hud():
	_apply_lefty_joystick_layout()

## Режим левши: движение справа, прицел слева (зеркально правше).
func _apply_lefty_joystick_layout():
	if _move_joy_c == null or _aim_joy_c == null:
		return
	var lefty := false
	if SaveManager != null:
		lefty = bool(SaveManager.get_setting("game", "lefty_mode", false))
	if lefty:
		_layout_joystick_bottom_right(_move_joy_c)
		_layout_joystick_bottom_left(_aim_joy_c, 60.0)
	else:
		_layout_joystick_bottom_left(_move_joy_c, 60.0)
		_layout_joystick_bottom_right(_aim_joy_c)

## edge_inset_left — сдвиг всего блока вправо от левого края (не сжимая зону 200 px).
func _layout_joystick_bottom_left(c: MarginContainer, edge_inset_left: float = 0.0):
	c.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = edge_inset_left
	c.offset_top = -200.0
	c.offset_right = 200.0 + edge_inset_left
	c.offset_bottom = 0.0
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	c.add_theme_constant_override("margin_left", 60)
	c.add_theme_constant_override("margin_right", 0)
	c.add_theme_constant_override("margin_top", 0)
	c.add_theme_constant_override("margin_bottom", 40)

	var is_tutorial = get_tree().has_group("tutorial")
	c.modulate.a = 1.0 if is_tutorial else 0.3

func _layout_joystick_bottom_right(c: MarginContainer):
	c.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	c.anchor_left = 1.0
	c.anchor_top = 1.0
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = -260.0
	c.offset_top = -200.0
	c.offset_right = -60.0
	c.offset_bottom = 0.0
	c.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN
	c.add_theme_constant_override("margin_left", 0)
	c.add_theme_constant_override("margin_right", 60)
	c.add_theme_constant_override("margin_top", 0)
	c.add_theme_constant_override("margin_bottom", 40)

	var is_tutorial = get_tree().has_group("tutorial")
	c.modulate.a = 1.0 if is_tutorial else 0.3

func set_joysticks_opacity(alpha: float):
	if _move_joy_c: _move_joy_c.modulate.a = alpha
	if _aim_joy_c: _aim_joy_c.modulate.a = alpha

func _setup_bases_label():
	var stats_container = find_child("Stats", true)
	if !stats_container: return
	var bases_row = HBoxContainer.new()
	bases_row.alignment = BoxContainer.ALIGNMENT_END
	stats_container.add_child(bases_row)
	_basesIcon = TextureRect.new()
	_basesIcon.texture = load("res://assets/backround/PNG/Props/Platform.png")
	_basesIcon.custom_minimum_size = Vector2(40, 40)
	_basesIcon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_basesIcon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_basesIcon.modulate = Color(1.0, 0.3, 0.3, 0.8)
	bases_row.add_child(_basesIcon)
	_basesLabel = Label.new()
	_basesLabel.add_theme_font_size_override("font_size", 32)
	bases_row.add_child(_basesLabel)
	call_deferred("_initialize_bases_count")

func _initialize_bases_count():
	await get_tree().process_frame
	_total_enemy_bases = get_tree().get_nodes_in_group("bases").filter(func(b): return b.get("type_base") == 1).size()
	_destroyed_count = 0
	_update_label_text()

func update_bases_count():
	_destroyed_count += 1
	_update_label_text()

func _update_label_text():
	if _basesLabel: _basesLabel.text = str(min(_destroyed_count, _total_enemy_bases)) + "/" + str(_total_enemy_bases)

func _update_level_display():
	if !_levelLabel: return
	var lvl = 1
	if SaveManager: lvl = SaveManager.current_level
	_levelLabel.text = "МИССИЯ " + str(((lvl-1)/5)+1) + "." + str(((lvl-1)%5)+1)

func _find_player_and_connect():
	var p = get_tree().get_first_node_in_group("players")
	if p != null:
		_player = p
		if not _player.health_changed.is_connected(_on_health_changed): _player.health_changed.connect(_on_health_changed)
		if not _player.lives_changed.is_connected(_on_lives_changed): _player.lives_changed.connect(_on_lives_changed)
		if not _player.money_changed.is_connected(_on_money_changed): _player.money_changed.connect(_on_money_changed)
		if _player.has_signal("ammo_changed") and not _player.ammo_changed.is_connected(_on_ammo_changed):
			_player.ammo_changed.connect(_on_ammo_changed)
		_on_health_changed(_player.get_current_health(), _player.get_max_health())
		_on_lives_changed(_player.get_lives())
		_on_money_changed(_player.get_money())
		_on_ammo_changed(_player.get("_type_bullet"))
	else:
		get_tree().create_timer(0.5).timeout.connect(_find_player_and_connect)

func _on_health_changed(curr, m):
	if _healthProgress:
		_healthProgress.max_value = m
		_healthProgress.value = curr
		_healthLabel.text = str(max(0,curr)) + "/" + str(m)

func _setup_progress_bar_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.8, 0.2)
	_healthProgress.add_theme_stylebox_override("fill", style)

func _on_lives_changed(l): if _livesLabel: _livesLabel.text = "Жизни: " + str(l)
func _on_money_changed(m): if _moneyLabel: _moneyLabel.text = str(m)

func _setup_ammo_selection():
	if has_node("AmmoPanelContainer"): get_node("AmmoPanelContainer").queue_free()
	var ammo_container = CenterContainer.new()
	ammo_container.name = "AmmoPanelContainer"
	add_child(ammo_container)
	ammo_container.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	ammo_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ammo_container.offset_top = -180
	ammo_container.offset_bottom = -30
	ammo_container.offset_left = -500
	ammo_container.offset_right = 500
	var ammo_panel = HBoxContainer.new()
	ammo_panel.name = "AmmoPanel"
	ammo_panel.add_theme_constant_override("separation", 25)
	ammo_container.add_child(ammo_panel)
	var tex = ["res://assets/future_tanks/PNG/Effects/Plasma.png","res://assets/future_tanks/PNG/Effects/Medium_Shell.png","res://assets/future_tanks/PNG/Effects/Light_Shell.png"]
	for i in range(3):
		var slot = Panel.new()
		slot.custom_minimum_size = Vector2(AMMO_BTN_SIZE, AMMO_BTN_SIZE)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.6); style.set_corner_radius_all(15); style.border_color = Color(0.4, 0.4, 0.4); style.set_border_width_all(3)
		slot.add_theme_stylebox_override("panel", style)
		ammo_panel.add_child(slot)
		var icon = TextureRect.new()
		icon.texture = load(tex[i]); icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); icon.offset_left = 18; icon.offset_top = 18; icon.offset_right = -18; icon.offset_bottom = -18
		slot.add_child(icon)
		var cooldown = Panel.new()
		var cd_style = StyleBoxFlat.new(); cd_style.bg_color = Color(0, 0, 0, 0.7); cd_style.set_corner_radius_all(15)
		cooldown.add_theme_stylebox_override("panel", cd_style); cooldown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); cooldown.visible = false
		cooldown.name = "Cooldown"
		slot.add_child(cooldown)
		var touch_btn = TouchScreenButton.new()
		touch_btn.shape = RectangleShape2D.new(); touch_btn.shape.size = Vector2(AMMO_BTN_SIZE, AMMO_BTN_SIZE)
		touch_btn.position = Vector2(AMMO_BTN_SIZE/2, AMMO_BTN_SIZE/2)
		touch_btn.pressed.connect(func(): if _player: _player._on_ammo_selected(i))
		slot.add_child(touch_btn)
		_ammo_buttons[i] = slot

func _process(delta):
	_update_ammo_cooldowns()
	_level_time += delta
	if _level_time >= BASE_MARKER_TIME: _show_base_markers = true
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
		var cd = slot.get_node("Cooldown")
		if timer and not timer.is_stopped() and i == _player.get("_type_bullet"):
			cd.visible = true; var ratio = timer.time_left / timer.wait_time
			cd.anchor_top = 1.0 - ratio; cd.anchor_bottom = 1.0; cd.offset_top = 0; cd.offset_bottom = 0
		else: cd.visible = false

func _on_ammo_changed(type):
	for i in _ammo_buttons:
		var slot = _ammo_buttons[i]
		var style = slot.get_theme_stylebox("panel").duplicate()
		if i == type: style.border_color = Color(1, 0.8, 0.2); slot.modulate.a = 1.0
		else: style.border_color = Color(0.4, 0.4, 0.4); slot.modulate.a = 0.6
		slot.add_theme_stylebox_override("panel", style)

func _on_marker_overlay_draw():
	if _player == null or not is_instance_valid(_player): return
	var view_size = get_viewport().get_visible_rect().size
	var cam_pos = _player.get_viewport().get_canvas_transform().affine_inverse().get_origin()
	var screen_rect = Rect2(cam_pos, view_size)

	# ИЕРАРХИЯ ОТРИСОВКИ (от нижних к верхним):

	# 1. МАРКЕР БОТОВ (Самый нижний слой)
	var enemy_bases = get_tree().get_nodes_in_group("bases").filter(func(b): return b.get("type_base") == 1)
	if enemy_bases.size() == 0:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy.get("_type_enemy") != 5:
				_draw_marker_for(enemy.global_position, Color(0, 0.5, 1, 0.7), _marker_icons.enemy, screen_rect, false, 1.0)

	# 2. МАРКЕР БАЗ ВРАГА
	if _show_base_markers:
		for base in get_tree().get_nodes_in_group("bases"):
			if is_instance_valid(base) and base.get("type_base") == 1:
				_draw_marker_for(base.global_position, Color(1, 1, 0, 0.7), _marker_icons.base, screen_rect, false, 1.0)

	# 3. МАРКЕР БАЗЫ ИГРОКА (При атаке)
	if _base_under_attack:
		_draw_marker_for(_player_base_pos, Color.GREEN, _marker_icons.warning, screen_rect, true, 1.2)

	# 4. МАРКЕР БОССА (Самый верхний слой)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.get("_type_enemy") == 5:
			_draw_marker_for(enemy.global_position, Color("#f34235"), _marker_icons.boss, screen_rect, false, 1.3)

func _draw_marker_for(target_pos: Vector2, color: Color, icon: Texture2D, screen_rect: Rect2, pulse: bool, max_scale: float):
	if screen_rect.has_point(target_pos): return
	var center = screen_rect.get_center(); var dir = (target_pos - center).normalized(); var dist = center.distance_to(target_pos)
	var marker_pos = _get_intersect_pos(center, dir, screen_rect); var margin = 40.0
	marker_pos.x = clamp(marker_pos.x, screen_rect.position.x + margin, screen_rect.end.x - margin)
	marker_pos.y = clamp(marker_pos.y, screen_rect.position.y + margin, screen_rect.end.y - margin)
	var draw_pos = _player.get_viewport().get_canvas_transform() * marker_pos
	var scale_factor = clamp(remap(dist, 800, 3000, max_scale, 0.5), 0.5, max_scale)
	if pulse: scale_factor *= 1.0 + (sin(Time.get_ticks_msec() * 0.005) * 0.12)

	_marker_overlay.draw_circle(draw_pos, 25 * scale_factor, Color(0, 0, 0, 0.4))
	_marker_overlay.draw_circle(draw_pos, 22 * scale_factor, Color(color.r, color.g, color.b, 0.7))
	if icon:
		var icon_size = Vector2(32, 32) * scale_factor
		_marker_overlay.draw_texture_rect(icon, Rect2(draw_pos - icon_size/2, icon_size), false, Color(1, 1, 1, 0.9))
	var pts = PackedVector2Array([draw_pos + dir * (35 * scale_factor), draw_pos + dir.rotated(0.4) * (25 * scale_factor), draw_pos + dir.rotated(-0.4) * (25 * scale_factor)])
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
