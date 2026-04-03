extends CanvasLayer

var _healthProgress: ProgressBar
var _healthLabel: Label
var _livesLabel: Label
var _moneyLabel: Label
var _basesLabel: Label
var _basesIcon: Sprite2D # Иконка базы
var _total_enemy_bases: int = 0
var _player
var _ammo_buttons = {}

func _ready():
	add_to_group("hud") # Регистрация для Field.gd
	var healthPanel = get_node_or_null("HealthPanel")
	if healthPanel == null:
		return
	
	_healthProgress = healthPanel.get_node_or_null("HealthProgress")
	_healthLabel = healthPanel.get_node_or_null("HealthLabel")
	_livesLabel = healthPanel.get_node_or_null("LivesLabel")
	_moneyLabel = healthPanel.get_node_or_null("MoneyLabel")
	
	_setup_bases_label(healthPanel) # Создаем метку баз
	_setup_ammo_selection()

	if _healthProgress == null or _healthLabel == null:
		return
	
	_setup_progress_bar_style()
	_healthProgress.min_value = 0
	_healthProgress.max_value = 100
	_healthProgress.value = 100
	_healthProgress.show_percentage = false

	call_deferred("_find_player_and_connect")

func _setup_bases_label(container: Control):
	# Контейнер для иконки и текста
	var bases_container = Control.new()
	bases_container.name = "BasesContainer"
	bases_container.position = Vector2(130, 15)
	container.add_child(bases_container)

	_basesIcon = Sprite2D.new()
	_basesIcon.texture = load("res://assets/backround/PNG/Props/Platform.png")
	_basesIcon.scale = Vector2(0.5, 0.5)
	_basesIcon.centered = true
	_basesIcon.position = Vector2(40, 40) # Центр иконки в контейнере
	_basesIcon.modulate = Color(1.0, 0.2, 0.2, 0.8) # Чуть прозрачный красный
	bases_container.add_child(_basesIcon)

	_basesLabel = Label.new()
	_basesLabel.name = "BasesLabel"
	# Центрируем текст прямо поверх иконки
	_basesLabel.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_basesLabel.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_basesLabel.size = Vector2(80, 80) # Размер совпадает с областью иконки
	_basesLabel.position = Vector2(0, 0)

	# Применяем стиль как у валюты
	_basesLabel.add_theme_font_size_override("font_size", 26)
	_basesLabel.add_theme_color_override("font_shadow_color", Color.BLACK)
	_basesLabel.add_theme_constant_override("shadow_offset_x", 2)
	_basesLabel.add_theme_constant_override("shadow_offset_y", 2)
	_basesLabel.add_theme_constant_override("shadow_outline_size", 1)
	bases_container.add_child(_basesLabel)

	call_deferred("_initialize_bases_count")

func _initialize_bases_count():
	# Ждем два кадра, чтобы сцена полностью стабилизировалась
	await get_tree().process_frame
	await get_tree().process_frame

	_total_enemy_bases = 0
	var all_bases = get_tree().get_nodes_in_group("bases")
	for b in all_bases:
		if b.type_base == 1: # ENEMY
			_total_enemy_bases += 1
	update_bases_count()

func update_bases_count():
	if _basesLabel == null: return

	var current_enemy_bases = 0
	var all_bases = get_tree().get_nodes_in_group("bases")
	for b in all_bases:
		if b.type_base == 1: # ENEMY
			current_enemy_bases += 1

	var destroyed = _total_enemy_bases - current_enemy_bases
	_basesLabel.text = str(destroyed) + "/" + str(_total_enemy_bases)

func _find_player_and_connect():
	# Универсальный поиск игрока через группу
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0:
		_player = players[0]
	
	if _player != null:
		# Правильное подключение сигналов в Godot 4
		if _player.has_signal("health_changed") and not _player.health_changed.is_connected(_on_health_changed):
			_player.health_changed.connect(_on_health_changed)

		if _player.has_signal("lives_changed") and not _player.lives_changed.is_connected(_on_lives_changed):
			_player.lives_changed.connect(_on_lives_changed)

		if _player.has_signal("money_changed") and not _player.money_changed.is_connected(_on_money_changed):
			_player.money_changed.connect(_on_money_changed)

		if _player.has_signal("ammo_changed") and not _player.ammo_changed.is_connected(_on_ammo_changed):
			_player.ammo_changed.connect(_on_ammo_changed)
			_on_ammo_changed(_player._type_bullet)

		var current_health = 100
		var max_health = 100
		var current_lives = 3
		var current_money = 0

		if _player.has_method("get_current_health"):
			current_health = _player.get_current_health()
		if _player.has_method("get_max_health"):
			max_health = _player.get_max_health()
		if _player.has_method("get_lives"):
			current_lives = _player.get_lives()
		if _player.has_method("get_money"):
			current_money = _player.get_money()

		var display_health = max(0, current_health)

		_healthProgress.max_value = max_health
		_healthProgress.value = display_health
		_healthLabel.text = str(display_health) + "/" + str(max_health)

		if _livesLabel != null:
			_livesLabel.text = "Жизни: " + str(current_lives)

		if _moneyLabel != null:
			_moneyLabel.text = str(current_money)

		_update_health_color(display_health, max_health)
	else:
		get_tree().create_timer(0.5).timeout.connect(_find_player_and_connect)

func _setup_progress_bar_style():
	if _healthProgress == null:
		return
	
	var background_style = StyleBoxFlat.new()
	background_style.bg_color = Color(0.1, 0.1, 0.1)
	background_style.border_width_bottom = 2
	background_style.border_width_top = 2
	background_style.border_width_left = 2
	background_style.border_width_right = 2
	background_style.border_color = Color(0.3, 0.3, 0.3)
	background_style.corner_radius_bottom_left = 5
	background_style.corner_radius_bottom_right = 5
	background_style.corner_radius_top_left = 5
	background_style.corner_radius_top_right = 5

	var progress_style = StyleBoxFlat.new()
	progress_style.bg_color = Color(0.2, 0.8, 0.2)
	progress_style.corner_radius_bottom_left = 5
	progress_style.corner_radius_bottom_right = 5
	progress_style.corner_radius_top_left = 5
	progress_style.corner_radius_top_right = 5

	_healthProgress.add_theme_stylebox_override("under", background_style)
	_healthProgress.add_theme_stylebox_override("fill", progress_style)

func _on_health_changed(current_health: int, max_health: int):
	if _healthProgress == null or _healthLabel == null:
		return

	var display_health = max(0, current_health)

	_healthProgress.value = display_health
	_healthLabel.text = str(display_health) + "/" + str(max_health)
	_update_health_color(display_health, max_health)

func _on_lives_changed(current_lives: int):
	if _livesLabel == null:
		return
	_livesLabel.text = "Жизни: " + str(current_lives)

func _on_money_changed(current_money: int):
	if _moneyLabel == null:
		return
	_moneyLabel.text = str(current_money)

func _update_health_color(current_health: int, max_health: int):
	var percent = float(current_health) / float(max_health)
	var style = _healthProgress.get_theme_stylebox("fill")
	if style is StyleBoxFlat:
		var flat_style = style as StyleBoxFlat
		if percent <= 0.3:
			flat_style.bg_color = Color(1, 0.2, 0.2)
		elif percent <= 0.6:
			flat_style.bg_color = Color(1, 0.8, 0.2)
		else:
			flat_style.bg_color = Color(0.2, 0.8, 0.2)

		_healthProgress.add_theme_stylebox_override("fill", flat_style)

func _setup_ammo_selection():
	if has_node("AmmoPanel"):
		get_node("AmmoPanel").queue_free()

	_ammo_buttons.clear()

	# Используем HBoxContainer для автоматического выравнивания и центрирования
	var ammo_panel = HBoxContainer.new()
	ammo_panel.name = "AmmoPanel"
	add_child(ammo_panel)

	# Центрируем панель внизу экрана (12 = PRESET_BOTTOM_CENTER)
	ammo_panel.set_anchors_and_offsets_preset(12)
	ammo_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	ammo_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ammo_panel.position.y -= 25 # Опустили максимально низко к краю
	ammo_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	ammo_panel.add_theme_constant_override("separation", 20)

	var textures = {
		0: ["res://assets/PlasmaUntoched копия.png", "res://assets/PlasmaToched.png"],
		1: ["res://assets/MediumBulletUntoched.png", "res://assets/MediumBulletToched.png"],
		2: ["res://assets/LightBulletUntoched.png", "res://assets/LightBulletToched.png"]
	}

	var ammo_types = ["PL", "MD", "LG"]

	for i in range(3):
		var slot = Control.new()
		slot.name = "Slot_" + str(i)
		slot.custom_minimum_size = Vector2(100, 110)
		ammo_panel.add_child(slot)

		# Фон и рамка (Panel)
		var bg = Panel.new()
		bg.name = "BG"
		bg.size = Vector2(100, 110)
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE # Пропускаем нажатия к TouchArea
		slot.add_child(bg)

		# Базовый стиль слота (темный с закругленными углами)
		var style = StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color(0.4, 0.4, 0.4)
		style.corner_radius_top_left = 10
		style.corner_radius_top_right = 10
		style.corner_radius_bottom_left = 10
		style.corner_radius_bottom_right = 10
		bg.add_theme_stylebox_override("panel", style)

		# Иконка снаряда
		var icon = Sprite2D.new()
		icon.name = "Icon"
		icon.texture = load(textures[i][0])
		icon.position = Vector2(50, 55)
		icon.scale = Vector2(0.2, 0.2)
		slot.add_child(icon)

		# Тип снаряда (текст сверху слева)
		var label = Label.new()
		label.text = ammo_types[i]
		label.position = Vector2(8, 5)
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_shadow_color", Color.BLACK)
		slot.add_child(label)

		# Невидимая область для нажатия через gui_input (без встроенных эффектов "кругов")
		var touch_area = Control.new()
		touch_area.name = "TouchArea"
		touch_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		slot.add_child(touch_area)

		_ammo_buttons[i] = slot

		# Обработка нажатия (тач или мышь) без визуального фидбека
		touch_area.gui_input.connect(func(event):
			if (event is InputEventScreenTouch and event.pressed) or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
				if _player:
					_player._on_ammo_selected(i)
		)

func _on_ammo_changed(type: int):
	for ammo_type in _ammo_buttons:
		var slot = _ammo_buttons[ammo_type]
		var bg = slot.get_node("BG")
		var icon = slot.get_node("Icon")

		# Клонируем стиль, чтобы изменения одного слота не влияли на другие
		var style = bg.get_theme_stylebox("panel").duplicate()

		var textures = {
			0: ["res://assets/PlasmaUntoched копия.png", "res://assets/PlasmaToched.png"],
			1: ["res://assets/MediumBulletUntoched.png", "res://assets/MediumBulletToched.png"],
			2: ["res://assets/LightBulletUntoched.png", "res://assets/LightBulletToched.png"]
		}

		if ammo_type == type:
			# Активный слот: золотая рамка и яркая иконка
			style.border_color = Color(1.0, 0.8, 0.2)
			style.bg_color = Color(0.2, 0.2, 0.15, 0.9)
			icon.texture = load(textures[ammo_type][1])
			slot.modulate.a = 1.0
		else:
			# Неактивный слот: серая рамка и прозрачность
			style.border_color = Color(0.4, 0.4, 0.4)
			style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
			icon.texture = load(textures[ammo_type][0])
			slot.modulate.a = 0.6

		bg.add_theme_stylebox_override("panel", style)
