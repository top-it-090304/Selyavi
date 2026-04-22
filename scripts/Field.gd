extends Node2D

var _musicPlayer: AudioStreamPlayer
var _pauseScene: PackedScene
var _currentPause: Node
var _victory_timer: Timer

@export var current_level: int = 1

func _ready():
	if SaveManager:
		current_level = SaveManager.current_level

	if name.contains("_"):
		var extracted = name.get_slice("_", 1).to_int()
		if extracted > 0:
			current_level = extracted
			if SaveManager: SaveManager.current_level = current_level

	_musicPlayer = get_node_or_null("MusicPlayer")
	var am = get_node_or_null("/root/AudioManager")

	if _musicPlayer != null:
		_musicPlayer.bus = "Music"
		if current_level % 5 == 0:
			_musicPlayer.stop()
			if am: am.play_boss()
		else:
			if am: am.stop()
			_musicPlayer.play()

	get_tree().node_added.connect(_on_node_added)

	for node in get_tree().get_nodes_in_group("bases"):
		_connect_base(node)

	for node in get_tree().get_nodes_in_group("enemies"):
		_connect_enemy(node)

	_victory_timer = Timer.new()
	_victory_timer.wait_time = 1.0
	_victory_timer.autostart = true
	_victory_timer.timeout.connect(_check_victory_conditions)
	add_child(_victory_timer)

	_pauseScene = load("res://scenes/MenuScenes/PauseScreen.tscn")
	call_deferred("_connect_player_lives")

	if current_level == 1:
		call_deferred("_launch_tutorial")

func _launch_tutorial():
	var tutorial_scene = load("res://scenes/MenuScenes/TutorialOverlay.tscn")
	if tutorial_scene:
		var tutorial = tutorial_scene.instantiate()
		add_child(tutorial)

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

func _on_base_destroyed(type: int):
	if type == 1:
		var players = get_tree().get_nodes_in_group("players")
		if players.size() > 0 and players[0].has_method("add_money"):
			players[0].add_money(200)

		var huds = get_tree().get_nodes_in_group("hud")
		if huds.size() > 0: huds[0].update_bases_count()

	if type == 0:
		_show_game_over_screen(false, "Ваша база уничтожена!")
	else:
		call_deferred("_check_victory_conditions")

func _check_victory_conditions():
	if get_tree().paused: return
	if _count_enemy_bases() == 0 and _count_all_enemies() == 0:
		_show_game_over_screen(true, "Миссия выполнена!")

func _count_enemy_bases() -> int:
	var count = 0
	for b in get_tree().get_nodes_in_group("bases"):
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			if b.get("type_base") == 1: count += 1
	return count

func _count_all_enemies() -> int:
	var count = 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(enemy) and not enemy.is_queued_for_deletion(): count += 1
	return count

func _show_game_over_screen(is_victory: bool, reason: String = ""):
	if get_tree().paused: return
	get_tree().paused = true

	if is_victory and SaveManager: SaveManager.unlock_level(current_level + 1)

	var canvas = CanvasLayer.new()
	canvas.layer = 100
	canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(canvas)

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center_container = CenterContainer.new()
	canvas.add_child(center_container)
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center_container.add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.1, 0.96)
	style.set_border_width_all(4)
	# ВОССТАНОВЛЕНО: Зеленая окантовка для победы, красная для поражения
	style.border_color = Color(0.2, 0.8, 0.2) if is_victory else Color(0.8, 0.2, 0.2)
	style.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30); margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30); margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 20); margin.add_child(vbox)
	var title = Label.new(); title.text = "ПОБЕДА!" if is_victory else "ПОРАЖЕНИЕ"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 48); vbox.add_child(title)
	var desc = Label.new(); desc.text = reason; desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; desc.custom_minimum_size = Vector2(400, 0); vbox.add_child(desc)

	var btn_container = VBoxContainer.new(); btn_container.add_theme_constant_override("separation", 12); vbox.add_child(btn_container)

	var style_btn = func(btn: Button):
		btn.custom_minimum_size = Vector2(0, 56)
		var btn_style = StyleBoxFlat.new(); btn_style.bg_color = Color(0.2, 0.22, 0.2); btn_style.set_corner_radius_all(12)
		btn.add_theme_stylebox_override("normal", btn_style); btn.add_theme_font_size_override("font_size", 24)

	if is_victory and current_level < 20:
		var btn_next = Button.new(); btn_next.text = "СЛЕДУЮЩАЯ МИССИЯ"; style_btn.call(btn_next); btn_container.add_child(btn_next)
		btn_next.pressed.connect(func(): get_tree().paused = false; var next_lvl = current_level + 1; if SaveManager: SaveManager.current_level = next_lvl; get_tree().change_scene_to_file("res://scenes/Levels/Level_" + str(next_lvl) + ".tscn"))

	var btn_retry = Button.new(); btn_retry.text = "ИГРАТЬ СНОВА"; style_btn.call(btn_retry); btn_container.add_child(btn_retry)
	btn_retry.pressed.connect(func(): get_tree().paused = false; get_tree().reload_current_scene())

	# ВОССТАНОВЛЕНО: Кнопка выбора миссии
	var btn_levels = Button.new(); btn_levels.text = "ВЫБОР МИССИИ"; style_btn.call(btn_levels); btn_container.add_child(btn_levels)
	btn_levels.pressed.connect(func(): get_tree().paused = false; get_tree().change_scene_to_file("res://scenes/MenuScenes/LevelSelector.tscn"))

	var btn_menu = Button.new(); btn_menu.text = "В ГЛАВНОЕ МЕНЮ"; style_btn.call(btn_menu); btn_container.add_child(btn_menu)
	btn_menu.pressed.connect(func(): get_tree().paused = false; get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn"))

func _cleanup_global_objects():
	for node in get_tree().root.get_children():
		if node == get_tree().current_scene: continue
		if node.is_in_group("enemies") or node.name.contains("Bullet"): node.queue_free()

func toggle_pause():
	if get_tree().paused: return
	get_tree().paused = true; var p = _pauseScene.instantiate(); p.process_mode = Node.PROCESS_MODE_ALWAYS; add_child(p)
