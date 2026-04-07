extends CanvasLayer

var _healthProgress: ProgressBar
var _healthLabel: Label
var _livesLabel: Label
var _moneyLabel: Label
var _basesLabel: Label
var _levelLabel: Label
var _basesIcon: TextureRect
var _total_enemy_bases: int = 0
var _destroyed_count: int = 0
var _player
var _ammo_buttons = {}

func _ready():
	add_to_group("hud")
	
	_healthProgress = find_child("HealthProgress", true)
	_healthLabel = find_child("HealthLabel", true)
	_livesLabel = find_child("LivesLabel", true)
	_moneyLabel = find_child("MoneyLabel", true)
	_levelLabel = find_child("LevelLabel", true)

	if _levelLabel:
		_levelLabel.position.y = 0

	_setup_bases_label()
	_setup_ammo_selection()
	_update_level_display()

	if _healthProgress:
		_setup_progress_bar_style()
		_healthProgress.value = 100

	call_deferred("_find_player_and_connect")

func _setup_bases_label():
	var stats_container = find_child("Stats", true)
	if !stats_container: return

	var bases_row = HBoxContainer.new()
	bases_row.name = "BasesRow"
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
	_basesLabel.name = "BasesLabel"
	_basesLabel.add_theme_font_size_override("font_size", 32)
	_basesLabel.add_theme_color_override("font_shadow_color", Color.BLACK)
	_basesLabel.add_theme_constant_override("shadow_outline_size", 4)
	bases_row.add_child(_basesLabel)

	call_deferred("_initialize_bases_count")

func _initialize_bases_count():
	await get_tree().process_frame
	await get_tree().process_frame
	_total_enemy_bases = get_tree().get_nodes_in_group("bases").filter(func(b): return b.get("type_base") == 1).size()
	_destroyed_count = 0
	_update_label_text()

func update_bases_count():
	_destroyed_count += 1
	_update_label_text()

func _update_label_text():
	if _basesLabel:
		_basesLabel.text = str(min(_destroyed_count, _total_enemy_bases)) + "/" + str(_total_enemy_bases)

func _update_level_display():
	if !_levelLabel: return
	var lvl = SaveManager.get_meta("current_level") if SaveManager and SaveManager.has_meta("current_level") else 1
	_levelLabel.text = "МИССИЯ " + str(((lvl-1)/5)+1) + "." + str(((lvl-1)%5)+1)

func _find_player_and_connect():
	var p = get_tree().get_first_node_in_group("players")
	if p != null:
		_player = p
		if not _player.health_changed.is_connected(_on_health_changed):
			_player.health_changed.connect(_on_health_changed)
		if not _player.lives_changed.is_connected(_on_lives_changed):
			_player.lives_changed.connect(_on_lives_changed)
		if not _player.money_changed.is_connected(_on_money_changed):
			_player.money_changed.connect(_on_money_changed)
		if _player.has_signal("ammo_changed") and not _player.ammo_changed.is_connected(_on_ammo_changed):
			_player.ammo_changed.connect(_on_ammo_changed)

		_on_health_changed(_player.get_current_health(), _player.get_max_health())
		_on_lives_changed(_player.get_lives())
		_on_money_changed(_player.get_money())
		_on_ammo_changed(_player._type_bullet)

		var joy = find_child("Joystick", true)
		var aim = find_child("Aim", true)

		if joy:
			if not joy.use_move_vector.is_connected(_player.use_move_vector):
				joy.use_move_vector.connect(_player.use_move_vector)

		if aim:
			aim.init(true)
			if not aim.use_move_vector.is_connected(_player.use_move_vector_aim):
				aim.use_move_vector.connect(_player.use_move_vector_aim)
			if not aim.fire_touch.is_connected(_player.fire_touch):
				aim.fire_touch.connect(_player.fire_touch)
	else:
		get_tree().create_timer(0.5).timeout.connect(_find_player_and_connect)

func _setup_progress_bar_style():
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.2, 0.8, 0.2)
	style.set_corner_radius_all(5)
	_healthProgress.add_theme_stylebox_override("fill", style)

func _on_health_changed(curr, m):
	if !_healthProgress: return
	_healthProgress.max_value = m
	_healthProgress.value = curr
	_healthLabel.text = str(max(0,curr)) + "/" + str(m)
	_update_health_color(curr, m)

func _update_health_color(curr, m):
	var p = float(curr)/m
	var style = _healthProgress.get_theme_stylebox("fill").duplicate()
	style.bg_color = Color(1,0.2,0.2) if p <= 0.3 else (Color(1,0.8,0.2) if p <= 0.6 else Color(0.2,0.8,0.2))
	_healthProgress.add_theme_stylebox_override("fill", style)

func _on_lives_changed(l): if _livesLabel: _livesLabel.text = "Жизни: " + str(l)
func _on_money_changed(m): if _moneyLabel: _moneyLabel.text = str(m)

func _setup_ammo_selection():
	if has_node("AmmoPanelContainer"): get_node("AmmoPanelContainer").queue_free()

	var ammo_container = MarginContainer.new()
	ammo_container.name = "AmmoPanelContainer"
	add_child(ammo_container)
	# Центрируем по горизонтали и привязываем к низу
	ammo_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	ammo_container.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ammo_container.offset_top = -140 # Сдвинул чуть выше из-за увеличения размера

	var ammo_panel = HBoxContainer.new()
	ammo_panel.name = "AmmoPanel"
	ammo_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	ammo_container.add_child(ammo_panel)

	var btn_size = 120 # Увеличил размер кнопок
	ammo_panel.add_theme_constant_override("separation", 25)

	var tex = [
		"res://assets/future_tanks/PNG/Effects/Plasma.png",
		"res://assets/future_tanks/PNG/Effects/Medium_Shell.png",
		"res://assets/future_tanks/PNG/Effects/Light_Shell.png"
	]

	for i in range(3):
		var slot = Control.new()
		slot.name = "Slot_" + str(i)
		slot.custom_minimum_size = Vector2(btn_size, btn_size)
		ammo_panel.add_child(slot)

		var btn = Button.new()
		btn.name = "Button"
		btn.size = Vector2(btn_size, btn_size)

		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.6)
		style.set_corner_radius_all(15)
		style.set_border_width_all(3)
		style.border_color = Color(0.4, 0.4, 0.4)

		btn.add_theme_stylebox_override("normal", style)
		slot.add_child(btn)

		var icon = TextureRect.new()
		icon.texture = load(tex[i])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size = Vector2(84, 84) # Увеличил иконку пропорционально
		icon.position = Vector2(18, 18) # Центрирование
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(icon)

		var cooldown = ColorRect.new()
		cooldown.name = "Cooldown"
		cooldown.color = Color(0, 0, 0, 0.7)
		cooldown.size = Vector2(btn_size, btn_size)
		cooldown.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cooldown.visible = false
		btn.add_child(cooldown)

		_ammo_buttons[i] = slot
		btn.pressed.connect(func(): if _player: _player._on_ammo_selected(i))

func _process(_delta):
	_update_ammo_cooldowns()

func _update_ammo_cooldowns():
	if _player == null or not is_instance_valid(_player): return
	var timer = _player.get("_shoot_timer")

	for i in range(3):
		if not _ammo_buttons.has(i): continue
		var cd = _ammo_buttons[i].get_node("Button/Cooldown")

		if timer and not timer.is_stopped() and i == _player.get("_type_bullet"):
			cd.visible = true
			var ratio = timer.time_left / timer.wait_time
			var h = _ammo_buttons[i].custom_minimum_size.y
			cd.size.y = h * ratio
			cd.position.y = h * (1.0 - ratio)
		else:
			cd.visible = false

func _on_ammo_changed(type):
	for i in _ammo_buttons:
		var btn = _ammo_buttons[i].get_node("Button")
		var style = btn.get_theme_stylebox("normal").duplicate()
		if i == type:
			style.border_color = Color(1, 0.8, 0.2)
			_ammo_buttons[i].modulate.a = 1.0
		else:
			style.border_color = Color(0.4, 0.4, 0.4)
			_ammo_buttons[i].modulate.a = 0.6
		btn.add_theme_stylebox_override("normal", style)
