extends Node2D

var _musicPlayer: AudioStreamPlayer
var _pauseScene: PackedScene
var _currentPause: Node
var _victory_timer: Timer # Таймер для периодической проверки условий победы

@export var current_level: int = 1

func _ready():
	# 1. Номер уровня
	if SaveManager and SaveManager.has_meta("current_level"):
		current_level = SaveManager.get_meta("current_level")
	else:
		var s_name = name
		if s_name.contains("_"):
			current_level = s_name.get_slice("_", 1).to_int()

	# 2. Музыка
	_musicPlayer = get_node_or_null("MusicPlayer")
	if _musicPlayer != null:
		_musicPlayer.bus = "Music"
		_musicPlayer.play()

	# 3. Следим за объектами
	get_tree().node_added.connect(_on_node_added)

	for node in get_tree().get_nodes_in_group("bases"):
		_connect_base(node)

	for node in get_tree().get_nodes_in_group("enemies"):
		_connect_enemy(node)

	# 4. Таймер подстраховки (проверяет победу раз в секунду)
	_victory_timer = Timer.new()
	_victory_timer.wait_time = 1.0
	_victory_timer.autostart = true
	_victory_timer.timeout.connect(_check_victory_conditions)
	add_child(_victory_timer)

	_pauseScene = load("res://scenes/MenuScenes/PauseScreen.tscn")
	call_deferred("_connect_player_lives")

func _on_node_added(node):
	if node.is_in_group("bases"):
		_connect_base(node)
	elif node.is_in_group("enemies"):
		_connect_enemy(node)

func _connect_base(base_node):
	if base_node.has_signal("base_state"):
		if not base_node.base_state.is_connected(_on_base_destroyed):
			base_node.base_state.connect(_on_base_destroyed)

func _connect_enemy(enemy_node):
	if enemy_node.has_signal("enemy_died"):
		if not enemy_node.enemy_died.is_connected(_on_enemy_died):
			enemy_node.enemy_died.connect(_on_enemy_died)

func _connect_player_lives():
	var player = get_node_or_null("PlayerTank")
	if player == null:
		var players = get_tree().get_nodes_in_group("players")
		if players.size() > 0: player = players[0]

	if player and player.has_signal("lives_changed"):
		if not player.lives_changed.is_connected(_on_player_lives_changed):
			player.lives_changed.connect(_on_player_lives_changed)

func _on_player_lives_changed(lives: int):
	if lives <= 0:
		_show_game_over_screen(false, "У вас закончились жизни")

func _on_enemy_died(_type: int):
	call_deferred("_check_victory_conditions")

func _on_base_destroyed(_type: int):
	# Если база уничтожена, даем игроку деньги
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0 and players[0].has_method("add_money"):
		players[0].add_money(200)

	var huds = get_tree().get_nodes_in_group("hud")
	if huds.size() > 0: huds[0].update_bases_count()

	call_deferred("_check_victory_conditions")

func _check_victory_conditions():
	if get_tree().paused: return # Не проверяем, если игра уже на паузе (победа/поражение)

	var bases_count = _count_enemy_bases()
	var enemies_count = _count_all_enemies()

	if bases_count == 0 and enemies_count == 0:
		_show_game_over_screen(true, "Миссия выполнена: Враг полностью уничтожен!")

func _count_enemy_bases() -> int:
	var count = 0
	for b in get_tree().get_nodes_in_group("bases"):
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			# В Godot 4 лучше использовать get() для Area2D
			if b.get("type_base") == 1: # 1 = ENEMY
				count += 1
	return count

func _count_all_enemies() -> int:
	var count = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
			count += 1
	return count

func _show_game_over_screen(is_victory: bool, reason: String = ""):
	if get_tree().paused: return
	get_tree().paused = true

	if is_victory and SaveManager:
		SaveManager.unlock_level(current_level + 1)

	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	# Затемнение фона
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.6)
	canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Контейнер для центровки
	var center_container = CenterContainer.new()
	canvas.add_child(center_container)
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(450, 420)
	center_container.add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.12, 0.11, 0.98)
	style.border_width_left = 4; style.border_width_top = 4; style.border_width_right = 4; style.border_width_bottom = 4
	style.border_color = Color(0.29, 0.34, 0.25)
	style.corner_radius_top_left = 20; style.corner_radius_top_right = 20; style.corner_radius_bottom_left = 20; style.corner_radius_bottom_right = 20
	style.shadow_size = 15; style.shadow_color = Color(0, 0, 0, 0.5)
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	panel.add_child(vbox)

	var title = Label.new()
	title.text = "ПОБЕДА!" if is_victory else "ПОРАЖЕНИЕ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2) if is_victory else Color(0.9, 0.3, 0.3))
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = reason
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.add_theme_font_size_override("font_size", 22)
	vbox.add_child(desc)

	var btn_container = VBoxContainer.new()
	btn_container.add_theme_constant_override("separation", 10)
	btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(btn_container)

	var style_btn = func(btn: Button):
		btn.custom_minimum_size = Vector2(320, 48)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.18, 0.21, 0.18)
		btn_style.border_width_bottom = 3
		btn_style.border_color = Color(0.29, 0.34, 0.25)
		btn_style.corner_radius_top_left = 10; btn_style.corner_radius_top_right = 10
		btn_style.corner_radius_bottom_left = 10; btn_style.corner_radius_bottom_right = 10
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_stylebox_override("hover", btn_style)
		btn.add_theme_stylebox_override("pressed", btn_style)

	if is_victory and current_level < 20:
		var btn_next = Button.new()
		btn_next.text = "СЛЕДУЮЩАЯ МИССИЯ"
		style_btn.call(btn_next)
		btn_container.add_child(btn_next)
		btn_next.pressed.connect(func():
			_cleanup_global_objects()
			get_tree().paused = false
			SaveManager.set_meta("current_level", current_level + 1)
			var next_path = "res://scenes/Levels/Level_" + str(current_level + 1) + ".tscn"
			get_tree().change_scene_to_file(next_path if FileAccess.file_exists(next_path) else "res://scenes/MenuScenes/LevelSelector.tscn")
		)

	var btn_retry = Button.new()
	btn_retry.text = "ИГРАТЬ СНОВА"
	style_btn.call(btn_retry)
	btn_container.add_child(btn_retry)
	btn_retry.pressed.connect(func():
		_cleanup_global_objects(); get_tree().paused = false; get_tree().reload_current_scene()
	)

	var btn_levels = Button.new()
	btn_levels.text = "ВЫБОР МИССИИ"
	style_btn.call(btn_levels)
	btn_container.add_child(btn_levels)
	btn_levels.pressed.connect(func():
		_cleanup_global_objects(); get_tree().paused = false; get_tree().change_scene_to_file("res://scenes/MenuScenes/LevelSelector.tscn")
	)

	var btn_menu = Button.new()
	btn_menu.text = "В ГЛАВНОЕ МЕНЮ"
	style_btn.call(btn_menu)
	btn_container.add_child(btn_menu)
	btn_menu.pressed.connect(func():
		_cleanup_global_objects(); get_tree().paused = false; get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
	)

func _cleanup_global_objects():
	for node in get_tree().root.get_children():
		if node == get_tree().current_scene: continue
		if node is Window: continue
		if node.is_in_group("enemies") or node.is_in_group("bullets") or node.name.contains("Bullet"):
			node.queue_free()

func _on_TouchScreenButton_pressed():
	if get_tree().paused: return
	get_tree().paused = true
	var p = _pauseScene.instantiate()
	p.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(p)
