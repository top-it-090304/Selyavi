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
var _ammo_anchor: Control

var _top_right: Control

var _total_enemy_bases: int = 0
var _destroyed_count: int = 0
var _player
var _ammo_buttons = {}

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

const AMMO_BTN_SIZE = 75
const AMMO_HITBOX_SIZE = 120
const AMMO_DEFAULT_LOADOUT = [2, 0, 1]

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
	_ammo_anchor = find_child("AmmoAnchor", true)

	if _move_joy_c: _move_joy_c.modulate.a = 0.4
	if _aim_joy_c: _aim_joy_c.modulate.a = 0.4
	if _top_right: _top_right.modulate.a = 0.5

	_setup_bases_label()
	_setup_buff_icon()
	_setup_marker_overlay()
	_setup_warning_label()

	var pause_btn = get_node_or_null("PauseButton")
	if pause_btn:
		pause_btn.pressed.connect(_on_pause_pressed)
		pause_btn.modulate.a = 0.5

	await get_tree().process_frame
	_setup_ammo_selection()
	_update_level_display()
	_start_level_label_fade()
	call_deferred("_find_player_and_connect")

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
	if !_ammo_anchor: return
	for c in _ammo_anchor.get_children(): c.queue_free()

	var loadout = AMMO_DEFAULT_LOADOUT
	if _player != null and is_instance_valid(_player) and _player.has_method("get_ammo_loadout"):
		loadout = _player.get_ammo_loadout()

	var angles = [-2.1, -1.57, -1.05]
	var radius = 180.0

	for i in range(3):
		var touch_btn = TouchScreenButton.new()
		var offset = Vector2(cos(angles[i]), sin(angles[i])) * radius
		touch_btn.position = offset - Vector2(AMMO_HITBOX_SIZE/2, AMMO_HITBOX_SIZE/2)

		var slot = Panel.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.custom_minimum_size = Vector2(AMMO_BTN_SIZE, AMMO_BTN_SIZE)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.4); style.set_corner_radius_all(40); style.border_color = Color(0.6, 0.6, 0.6); style.set_border_width_all(2)
		slot.add_theme_stylebox_override("panel", style)
		slot.position = Vector2((AMMO_HITBOX_SIZE - AMMO_BTN_SIZE)/2, (AMMO_HITBOX_SIZE - AMMO_BTN_SIZE)/2)
		touch_btn.add_child(slot)

		var icon = TextureRect.new()
		var ammo_id = loadout[i] if i < loadout.size() else AMMO_DEFAULT_LOADOUT[i]
		icon.texture = load(_ammo_icon_path(ammo_id))
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); icon.offset_left = 10; icon.offset_top = 10; icon.offset_right = -10; icon.offset_bottom = -10
		slot.add_child(icon)

		var cooldown = TextureProgressBar.new()
		cooldown.name = "Cooldown"
		cooldown.fill_mode = TextureProgressBar.FILL_CLOCKWISE
		cooldown.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var img = Image.create(64, 64, false, Image.FORMAT_RGBA8); img.fill(Color.WHITE)
		cooldown.texture_progress = ImageTexture.create_from_image(img)
		cooldown.tint_progress = Color(0, 0, 0, 0.7); cooldown.visible = false
		slot.add_child(cooldown)

		touch_btn.shape = CircleShape2D.new(); touch_btn.shape.radius = AMMO_HITBOX_SIZE/2
		touch_btn.pressed.connect(func(): if _player: _player._on_ammo_selected(i))
		_ammo_anchor.add_child(touch_btn)
		_ammo_buttons[i] = slot

func _ammo_icon_path(ammo_id: int) -> String:
	match ammo_id:
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

func _update_ammo_cooldowns():
	if _player == null or not is_instance_valid(_player): return
	var timer = _player.get("_shoot_timer")
	for i in range(3):
		if not _ammo_buttons.has(i): continue
		var slot = _ammo_buttons[i]
		var cd = slot.get_node("Cooldown")
		if timer and not timer.is_stopped() and i == _player.get("_current_ammo_slot"):
			cd.visible = true
			cd.value = (timer.time_left / timer.wait_time) * 100
		else: cd.visible = false

func _on_ammo_changed(type):
	for i in _ammo_buttons:
		var slot = _ammo_buttons[i]
		slot.modulate.a = 1.0 if i == type else 0.5
		var style = slot.get_theme_stylebox("panel").duplicate()
		style.border_color = Color(1, 0.8, 0) if i == type else Color(0.6, 0.6, 0.6)
		slot.add_theme_stylebox_override("panel", style)

func _setup_buff_icon():
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
	_warningLabel = find_child("WarningLabel", true)

func trigger_base_attack_warning(base_pos: Vector2):
	_base_under_attack = true; _player_base_pos = base_pos; _attack_warning_timer = 3.0
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

func _find_player_and_connect():
	_player = get_tree().get_first_node_in_group("players")
	if _player:
		if not _player.health_changed.is_connected(_on_health_changed): _player.health_changed.connect(_on_health_changed)
		if not _player.lives_changed.is_connected(_on_lives_changed): _player.lives_changed.connect(_on_lives_changed)
		if not _player.money_changed.is_connected(_on_money_changed): _player.money_changed.connect(_on_money_changed)
		if _player.has_signal("ammo_changed") and not _player.ammo_changed.is_connected(_on_ammo_changed):
			_player.ammo_changed.connect(_on_ammo_changed)
		_on_health_changed(_player.get_current_health(), _player.get_max_health())
		_on_lives_changed(_player.get_lives())
		_on_money_changed(_player.get_money())
		_on_ammo_changed(_player.get("_current_ammo_slot"))
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

func highlight_health():
	if _healthProgress:
		var tween = create_tween().set_parallel(true)
		tween.tween_property(_healthProgress, "modulate:a", 1.0, 0.2)
		if _healthLabel: tween.tween_property(_healthLabel, "modulate:a", 1.0, 0.2)
		get_tree().create_timer(2.0).timeout.connect(func():
			var fade = create_tween().set_parallel(true)
			fade.tween_property(_healthProgress, "modulate:a", 0.5, 1.0)
			if _healthLabel: fade.tween_property(_healthLabel, "modulate:a", 0.5, 1.0)
		)

func _on_marker_overlay_draw():
	if _player == null or not is_instance_valid(_player): return
	var cam_transform = _player.get_viewport().get_canvas_transform(); var cam_pos = cam_transform.affine_inverse().get_origin(); var cam_scale = cam_transform.get_scale(); var view_size = get_viewport().get_visible_rect().size / cam_scale; var screen_rect = Rect2(cam_pos, view_size)
	var enemy_bases = get_tree().get_nodes_in_group("bases").filter(func(b): return b.get("type_base") == 1)
	if enemy_bases.size() == 0:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and enemy.get("_type_enemy") != 5: _draw_marker_for(enemy.global_position, Color(0, 0.5, 1, 0.7), _marker_icons.enemy, screen_rect, false, 1.0)
	if _show_base_markers:
		for base in get_tree().get_nodes_in_group("bases"):
			if is_instance_valid(base) and base.get("type_base") == 1: _draw_marker_for(base.global_position, Color(1, 1, 0, 0.7), _marker_icons.base, screen_rect, false, 1.0)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and enemy.get("_type_enemy") == 5: _draw_marker_for(enemy.global_position, Color("#f34235"), _marker_icons.boss, screen_rect, false, 1.3)

func _draw_marker_for(target_pos: Vector2, color: Color, icon: Texture2D, screen_rect: Rect2, pulse: bool, max_scale: float):
	if screen_rect.has_point(target_pos): return
	var center = screen_rect.get_center(); var dir = (target_pos - center).normalized(); var dist = center.distance_to(target_pos); var marker_pos = _get_intersect_pos(center, dir, screen_rect); var margin = 80.0
	marker_pos.x = clamp(marker_pos.x, screen_rect.position.x + margin, screen_rect.end.x - margin); marker_pos.y = clamp(marker_pos.y, screen_rect.position.y + margin, screen_rect.end.y - margin)
	var draw_pos = _player.get_viewport().get_canvas_transform() * marker_pos; var base_scale = clamp(remap(dist, 800, 3000, max_scale, 0.5), 0.5, max_scale); var scale_factor = base_scale * (SaveManager.get_setting("game", "marker_scale", 1.0) if SaveManager else 1.0)
	if pulse: scale_factor *= 1.0 + (sin(Time.get_ticks_msec() * 0.005) * 0.12)
	_marker_overlay.draw_circle(draw_pos, 25 * scale_factor, Color(0, 0, 0, 0.4)); _marker_overlay.draw_circle(draw_pos, 22 * scale_factor, Color(color.r, color.g, color.b, 0.7))
	if icon:
		var icon_size = Vector2(32, 32) * scale_factor; _marker_overlay.draw_texture_rect(icon, Rect2(draw_pos - icon_size/2, icon_size), false, Color(1, 1, 1, 0.9))
	var pts = PackedVector2Array([draw_pos + dir * (35 * scale_factor), draw_pos + dir.rotated(0.4) * (20 * scale_factor), draw_pos + dir.rotated(-0.4) * (20 * scale_factor)]); _marker_overlay.draw_colored_polygon(pts, Color(color.r, color.g, color.b, 0.7))

func _get_intersect_pos(center: Vector2, dir: Vector2, rect: Rect2) -> Vector2:
	var t_max = Vector2.ZERO
	if dir.x > 0: t_max.x = (rect.end.x - center.x) / dir.x
	elif dir.x < 0: t_max.x = (rect.position.x - center.x) / dir.x
	else: t_max.x = 1e10
	if dir.y > 0: t_max.y = (rect.end.y - center.y) / dir.y
	elif dir.y < 0: t_max.y = (rect.position.y - center.y) / dir.y
	else: t_max.y = 1e10
	return center + dir * min(t_max.x, t_max.y)
