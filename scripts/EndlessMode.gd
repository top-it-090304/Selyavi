extends "res://scripts/Field.gd"

const BASE_WAVE_POINTS := 100.0
const WAVE_POINTS_GROWTH := 25.0
const SPAWN_TICK_INTERVAL := 1.0
const INTERMISSION_TIME := 6.0
const BOSS_WAVE_INTERVAL := 5
const WAVE_MONEY_BASE := 50
const WAVE_MONEY_PER_WAVE := 15

const ENEMY_POOL := [
	{"res": "res://resources/enemies/enemy_light.tres", "cost": 10.0, "min_wave": 1},
	{"res": "res://resources/enemies/enemy_medium.tres", "cost": 16.0, "min_wave": 1},
	{"res": "res://resources/enemies/enemy_heavy.tres", "cost": 28.0, "min_wave": 3},
	{"res": "res://resources/enemies/enemy_triple.tres", "cost": 32.0, "min_wave": 4},
	{"res": "res://resources/enemies/enemy_scout.tres", "cost": 24.0, "min_wave": 6},
	{"res": "res://resources/enemies/enemy_kamikaze.tres", "cost": 25.0, "min_wave": 8},
]

const REGULAR_MAPS := [
	"res://scenes/Levels/EndlessMode/RegularWaves/SpringMap1.tscn",
	"res://scenes/Levels/EndlessMode/RegularWaves/SummerMap1.tscn",
	"res://scenes/Levels/EndlessMode/RegularWaves/WinterMap1.tscn",
	"res://scenes/Levels/EndlessMode/RegularWaves/PostSummerMap1.tscn"
]

const BOSS_RES := "res://resources/enemies/enemy_boss.tres"
const TWIN_BOSS_SCENE := preload("res://scenes/Tank/TwinBoss.tscn")
const TWIN_WAVE_INTERVAL := BOSS_WAVE_INTERVAL * 2

var wave_number: int = 0
var _wave_points_left: float = 0.0
var _wave_in_progress: bool = false
var _spawn_points: Array = []
var _spawn_timer: Timer
var _wave_check_timer: Timer
var _enemy_scene: PackedScene
var _current_map_node: Node2D = null

func _ready():
	if SaveManager:
		SaveManager.current_level = 99
	current_level = 99

	_musicPlayer = get_node_or_null("MusicPlayer")
	var am = get_node_or_null("/root/AudioManager")
	if _musicPlayer != null:
		_musicPlayer.bus = "Music"
		if am: am.stop()
		_musicPlayer.play()

	get_tree().node_added.connect(_on_node_added)

	_pauseScene = load("res://scenes/MenuScenes/PauseScreen.tscn")
	call_deferred("_connect_player_lives")

	_enemy_scene = load("res://scenes/Tank/Enemy.tscn")

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = SPAWN_TICK_INTERVAL
	add_child(_spawn_timer)
	_spawn_timer.timeout.connect(_on_spawn_tick)

	_wave_check_timer = Timer.new()
	_wave_check_timer.wait_time = 1.0
	_wave_check_timer.autostart = true
	add_child(_wave_check_timer)
	_wave_check_timer.timeout.connect(_check_wave_cleared)

	# Запускаем первую волну с загрузкой карты
	_start_next_wave()

func _start_next_wave():
	wave_number += 1

	# Логика смены карты:
	# 1. Если это самая первая волна.
	# 2. Если это волна босса (кратна 5).
	# 3. Если это волна ПОСЛЕ босса (6, 11, 16...).
	if wave_number == 1 or wave_number % BOSS_WAVE_INTERVAL == 0 or (wave_number - 1) % BOSS_WAVE_INTERVAL == 0:
		_switch_to_random_map()
	else:
		_begin_wave_logic()

func _switch_to_random_map():
	# Определяем, какую карту выбрать
	var map_pool = REGULAR_MAPS
	# В будущем здесь будет проверка на BOSS_MAPS

	var random_map_path = map_pool[randi() % map_pool.size()]
	_load_map(random_map_path)

func _load_map(path: String):
	# Затемнение экрана для красоты перехода
	_fade_screen(true)
	await get_tree().create_timer(0.5).timeout

	# Удаляем старую карту если она была
	if _current_map_node:
		_current_map_node.queue_free()
		_current_map_node = null

	# Загружаем новую
	var map_scene = load(path)
	if not map_scene:
		_fade_screen(false)
		return

	_current_map_node = map_scene.instantiate()
	add_child(_current_map_node)
	# Перемещаем карту в начало списка детей, чтобы она была под игроком
	move_child(_current_map_node, 0)

	# Настройка спавн-точек
	var spawn_root = _current_map_node.get_node_or_null("EnemySpawnPoints")
	if spawn_root:
		_spawn_points = spawn_root.get_children()

	# Настройка камеры
	var player = get_tree().get_first_node_in_group("players")
	if player:
		var cam = player.get_node_or_null("Camera2D")
		if cam:
			# Берем лимиты из скрипта карты EndlessMap.gd
			cam.limit_right = _current_map_node.get("limit_right") if "limit_right" in _current_map_node else 3967
			cam.limit_bottom = _current_map_node.get("limit_bottom") if "limit_bottom" in _current_map_node else 3044

		# Телепортация игрока
		var start_pos = _current_map_node.get_node_or_null("PlayerStart")
		if start_pos:
			player.global_position = start_pos.global_position

	_fade_screen(false)
	await get_tree().create_timer(0.5).timeout
	_begin_wave_logic()

func _begin_wave_logic():
	if AchievementManager: AchievementManager.report("endless_wave", wave_number)
	_wave_points_left = BASE_WAVE_POINTS + (wave_number - 1) * WAVE_POINTS_GROWTH
	_wave_in_progress = true
	_update_wave_hud()

	if wave_number % TWIN_WAVE_INTERVAL == 0:
		_spawn_twin_bosses()
	elif wave_number % BOSS_WAVE_INTERVAL == 0:
		_spawn_from_resource(BOSS_RES)

	_spawn_timer.start()

func _fade_screen(out: bool):
	var hud = get_tree().get_first_node_in_group("hud")
	if not hud: return

	var overlay = hud.get_node_or_null("FadeOverlay")
	if not overlay:
		overlay = ColorRect.new()
		overlay.name = "FadeOverlay"
		overlay.color = Color(0, 0, 0, 0)
		overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(overlay)

	var tween = create_tween()
	tween.tween_property(overlay, "color:a", 1.0 if out else 0.0, 0.4)

func _on_spawn_tick():
	if _wave_points_left <= 0:
		_spawn_timer.stop()
		return

	var candidates = ENEMY_POOL.filter(func(e): return wave_number >= e.min_wave and e.cost <= _wave_points_left)
	if candidates.is_empty():
		_spawn_timer.stop()
		return

	var pick = candidates[randi() % candidates.size()]
	if _spawn_from_resource(pick.res):
		_wave_points_left -= pick.cost

func _spawn_from_resource(path: String) -> bool:
	if _spawn_points.is_empty(): return false
	var marker = _spawn_points[randi() % _spawn_points.size()]
	var pos = _get_safe_spawn_pos(marker.global_position)
	if pos == Vector2.ZERO: return false

	var data = load(path)
	var scene_to_use = _enemy_scene
	if data and data.get("enemy_type") == 9: # KAMIKAZE
		scene_to_use = load("res://scenes/Tank/KamikazeEnemy.tscn")

	var enemy = scene_to_use.instantiate()
	enemy.enemy_data = data
	enemy.global_position = pos
	add_child(enemy)
	return true

func _get_safe_spawn_pos(origin: Vector2) -> Vector2:
	for attempts in range(30):
		var angle = randf_range(0, TAU)
		var pos = origin + Vector2(cos(angle), sin(angle)) * randf_range(0, 150)
		if _is_pos_on_nav_mesh(pos) and _is_pos_safe(pos):
			return pos
	return Vector2.ZERO

func _is_pos_on_nav_mesh(pos: Vector2) -> bool:
	var map = get_world_2d().get_navigation_map()
	var closest_pos = NavigationServer2D.map_get_closest_point(map, pos)
	return pos.distance_to(closest_pos) < 50.0

func _is_pos_safe(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var shape = CircleShape2D.new(); shape.radius = 45.0
	var query = PhysicsShapeQueryParameters2D.new(); query.set_shape(shape); query.transform = Transform2D(0, pos)
	var results = space_state.intersect_shape(query)
	for result in results:
		if result.collider is TileMap or result.collider is StaticBody2D or result.collider is CharacterBody2D: return false
	return true

func _check_wave_cleared():
	if not _wave_in_progress: return
	if not _spawn_timer.is_stopped(): return
	if _count_all_enemies() > 0: return

	_wave_in_progress = false
	var players = get_tree().get_nodes_in_group("players")
	if players.size() > 0 and players[0].has_method("add_money"):
		players[0].add_money(WAVE_MONEY_BASE + wave_number * WAVE_MONEY_PER_WAVE)

	get_tree().create_timer(INTERMISSION_TIME).timeout.connect(_start_next_wave)

func _update_wave_hud():
	var huds = get_tree().get_nodes_in_group("hud")
	if huds.size() > 0 and huds[0].has_method("set_header_label"):
		huds[0].set_header_label("ВОЛНА " + str(wave_number))

func _on_base_destroyed(type: int):
	if type == 0: _show_endless_game_over_screen()

func _on_player_lives_changed(lives: int):
	if lives <= 0: _show_endless_game_over_screen()

func _show_endless_game_over_screen():
	if get_tree().paused: return
	get_tree().paused = true

	var canvas = CanvasLayer.new(); canvas.layer = 100; canvas.process_mode = Node.PROCESS_MODE_ALWAYS; add_child(canvas)
	var overlay = ColorRect.new(); overlay.color = Color(0, 0, 0, 0.7); canvas.add_child(overlay); overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center_container = CenterContainer.new(); canvas.add_child(center_container); center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel = PanelContainer.new(); panel.custom_minimum_size = Vector2(480, 0); center_container.add_child(panel)
	var style = StyleBoxFlat.new(); style.bg_color = Color(0.1, 0.11, 0.1, 0.96); style.set_border_width_all(4); style.border_color = Color(0.8, 0.2, 0.2); style.set_corner_radius_all(20); panel.add_theme_stylebox_override("panel", style)
	var margin = MarginContainer.new(); margin.add_theme_constant_override("margin_left", 30); margin.add_theme_constant_override("margin_right", 30); margin.add_theme_constant_override("margin_top", 30); margin.add_theme_constant_override("margin_bottom", 30); panel.add_child(margin)
	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 20); margin.add_child(vbox)
	var title = Label.new(); title.text = "ПОРАЖЕНИЕ"; title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size", 48); vbox.add_child(title)
	var desc = Label.new(); desc.text = "Вы продержались до волны " + str(wave_number); desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART; desc.custom_minimum_size = Vector2(400, 0); vbox.add_child(desc)
	var btn_container = VBoxContainer.new(); btn_container.add_theme_constant_override("separation", 12); vbox.add_child(btn_container)
	var style_btn = func(btn: Button):
		btn.custom_minimum_size = Vector2(0, 56)
		var btn_style = StyleBoxFlat.new(); btn_style.bg_color = Color(0.2, 0.22, 0.2); btn_style.set_corner_radius_all(12)
		btn.add_theme_stylebox_override("normal", btn_style); btn.add_theme_font_size_override("font_size", 24)
	var btn_retry = Button.new(); btn_retry.text = "ИГРАТЬ СНОВА"; style_btn.call(btn_retry); btn_container.add_child(btn_retry)
	btn_retry.pressed.connect(func(): get_tree().paused = false; get_tree().reload_current_scene())
	var btn_menu = Button.new(); btn_menu.text = "В ГЛАВНОЕ МЕНЮ"; style_btn.call(btn_menu); btn_container.add_child(btn_menu)
	btn_menu.pressed.connect(func(): get_tree().paused = false; get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn"))

func _check_victory_conditions(): pass
