extends Node2D

var _musicPlayer: AudioStreamPlayer
var _pauseScene: PackedScene
var _currentPause: Node
var _enemyBase: Base
var _playerBase: Base

func _ready():
	_musicPlayer = get_node_or_null("MusicPlayer")
	if _musicPlayer != null:
		_musicPlayer.bus = "Music"
		_musicPlayer.play()

	# Автоматически подписываемся на ВСЕ базы, которые есть или появятся на сцене
	get_tree().node_added.connect(_on_node_added)
	# И на те, что уже есть
	for node in get_tree().get_nodes_in_group("bases"):
		_connect_base(node)
	
	_pauseScene = load("res://scenes/MenuScenes/PauseScreen.tscn")
	call_deferred("_connect_player_lives")

func _on_node_added(node):
	if node.is_in_group("bases"):
		_connect_base(node)

func _connect_base(base_node):
	if base_node.has_signal("base_state"):
		if not base_node.base_state.is_connected(_on_base_destroyed):
			base_node.base_state.connect(_on_base_destroyed)

func _connect_player_lives():
	var player = get_node_or_null("PlayerTank")
	if player and player.has_signal("lives_changed"):
		player.lives_changed.connect(_on_player_lives_changed)

func _on_player_lives_changed(lives: int):
	if lives <= 0:
		_show_game_over_screen(false, "У вас закончились жизни")

func _on_base_destroyed(type: int):
	# type == 0 (PLAYER), type == 1 (ENEMY)
	var is_enemy_base = (type == 1)

	if is_enemy_base:
		var players = get_tree().get_nodes_in_group("players")
		var player = players[0] if players.size() > 0 else null
		if player and player.has_method("add_money"):
			player.add_money(200)

		# Оповещаем HUD об уничтожении базы
		var huds = get_tree().get_nodes_in_group("hud")
		if huds.size() > 0:
			huds[0].update_bases_count()

		# Проверяем, остались ли еще вражеские базы
		await get_tree().process_frame # Ждем, пока база удалится из группы
		var enemy_bases = []
		for b in get_tree().get_nodes_in_group("bases"):
			if b.type_base == 1: # ENEMY
				enemy_bases.append(b)

		if enemy_bases.size() == 0:
			_show_game_over_screen(true, "Все базы противника уничтожены!")
	else:
		# Уничтожена база игрока
		_show_game_over_screen(false, "Ваша база была уничтожена")

func _show_game_over_screen(is_victory: bool, reason: String = ""):
	get_tree().paused = true

	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	# Затемнение заднего фона
	var overlay = ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0, 0, 0, 0.6)
	canvas.add_child(overlay)

	# Основная панель
	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(450, 320)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	canvas.add_child(panel)

	# Стиль в духе меню (Dark Green Theme)
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.12, 0.11, 0.98) # #1c1f1c
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.border_color = Color(0.29, 0.34, 0.25) # #4a5740
	style.corner_radius_top_left = 20
	style.corner_radius_top_right = 20
	style.corner_radius_bottom_left = 20
	style.corner_radius_bottom_right = 20
	style.shadow_size = 15
	style.shadow_color = Color(0, 0, 0, 0.5)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 25)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(vbox)

	# Небольшой отступ сверху
	var top_margin = Control.new()
	top_margin.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(top_margin)

	var title = Label.new()
	title.text = "ПОБЕДА!" if is_victory else "ПОРАЖЕНИЕ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2) if is_victory else Color(0.9, 0.3, 0.3))
	title.add_theme_color_override("font_shadow_color", Color.BLACK)
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = reason
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 22)
	desc.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(desc)

	# Контейнер для кнопок
	var btn_container = VBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 15)
	btn_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)

	# Функция для стилизации кнопок
	var style_btn = func(btn: Button):
		btn.custom_minimum_size = Vector2(280, 55)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.18, 0.21, 0.18)
		btn_style.border_width_bottom = 3
		btn_style.border_color = Color(0.29, 0.34, 0.25)
		btn_style.corner_radius_top_left = 10
		btn_style.corner_radius_top_right = 10
		btn_style.corner_radius_bottom_left = 10
		btn_style.corner_radius_bottom_right = 10
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("hover", btn_style)
		btn.add_theme_stylebox_override("pressed", btn_style)
		btn.add_theme_font_size_override("font_size", 20)

	var btn_retry = Button.new()
	btn_retry.text = "ИГРАТЬ СНОВА"
	style_btn.call(btn_retry)
	btn_container.add_child(btn_retry)

	var btn_menu = Button.new()
	btn_menu.text = "В ГЛАВНОЕ МЕНЮ"
	style_btn.call(btn_menu)
	btn_container.add_child(btn_menu)

	btn_retry.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene()
	)

	btn_menu.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
	)

func _on_TouchScreenButton_pressed():
	if get_tree().paused:
		return
	
	get_tree().paused = true
	
	_currentPause = _pauseScene.instantiate()
	# PauseScreen уже является CanvasLayer, добавляем его напрямую
	_currentPause.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_currentPause)
