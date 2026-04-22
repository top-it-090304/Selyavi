extends "res://scripts/Tank/Enemy.gd"

var _spawn_timer: Timer
var _enemy_scene: PackedScene
var _hp_bar: ProgressBar
var _hp_bar_label: Label
var _spawn_attempts: int = 0
var _max_spawn_attempts: int = 28
var _boss_minions: Array = []
var _max_minions: int = 3 # Лимит остается неизменным

var _phase2_active: bool = false
var _is_transforming: bool = false
const PHASE2_HP_RATIO: float = 0.5

func _prune_minion_list():
	_boss_minions = _boss_minions.filter(func(n):
		return is_instance_valid(n) and not n.is_queued_for_deletion()
	)

func _ready():
	_type_enemy = TypeEnemy.BOSS
	super._ready()
	
	_setup_hp_bar()
	
	_enemy_scene = load("res://scenes/Tank/Enemy.tscn")
	
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = 7.0
	_spawn_timer.autostart = true
	_spawn_timer.timeout.connect(_spawn_minion)
	add_child(_spawn_timer)

	# Начальные параметры дальности
	_notice_range = 1000.0
	_attack_range = 1000.0

func _setup_hp_bar():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = _max_hp
	_hp_bar.value = _hp
	_hp_bar.show_percentage = false
	
	_hp_bar.custom_minimum_size = Vector2(450, 24)
	_hp_bar.anchor_left = 0.5; _hp_bar.anchor_right = 0.5; _hp_bar.anchor_top = 1.0; _hp_bar.anchor_bottom = 0.1
	_hp_bar.offset_left = -225; _hp_bar.offset_right = 225; _hp_bar.offset_top = 25; _hp_bar.offset_bottom = 50
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.4)
	style_bg.set_border_width_all(2)
	style_bg.border_color = Color(0.4, 0.4, 0.4, 0.6)
	_hp_bar.add_theme_stylebox_override("background", style_bg)
	
	_set_bar_fill_color(Color(0.8, 0.0, 0.0, 0.6))
	canvas.add_child(_hp_bar)

	_hp_bar_label = Label.new()
	_hp_bar_label.text = "ПРИЗЫВАТЕЛЬ"
	_hp_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_bar_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3, 0.8))
	_hp_bar_label.custom_minimum_size = Vector2(450, 20)
	_hp_bar_label.anchor_left = 0.5; _hp_bar_label.anchor_right = 0.5; _hp_bar_label.anchor_top = 1.0; _hp_bar_label.anchor_bottom = 0.1
	_hp_bar_label.offset_left = -225; _hp_bar_label.offset_right = 225; _hp_bar_label.offset_top = 0; _hp_bar_label.offset_bottom = 25
	canvas.add_child(_hp_bar_label)

func _set_bar_fill_color(color: Color):
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = color
	_hp_bar.add_theme_stylebox_override("fill", style_fill)

func take_damage(damage: int):
	if _is_transforming: return
	super.take_damage(damage)
	if _hp_bar: _hp_bar.value = _hp

	if not _phase2_active and float(_hp) / float(_max_hp) <= PHASE2_HP_RATIO:
		_activate_phase2()

func _activate_phase2():
	_phase2_active = true
	_is_transforming = true

	_patrol_speed += 40
	_chase_speed += 40

	# Увеличиваем дальность атаки во 2 фазе
	_notice_range = 1200.0
	_attack_range = 1200.0

	_fire_rate *= 0.6

	if _hp_bar_label: _hp_bar_label.text = "ПРИЗЫВАТЕЛЬ - В ЯРОСТИ"
	_set_bar_fill_color(Color(1.0, 0.1, 0.1, 0.8))

	var tween = create_tween()
	tween.tween_property(self, "rotation_degrees", rotation_degrees + 720, 2.0).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)

	for i in range(3):
		get_tree().create_timer(i * 0.4).timeout.connect(_spawn_independent_minion)

	get_tree().create_timer(2.0).timeout.connect(func(): _is_transforming = false)

func _fire_at_pos(pos: Vector2):
	if _is_transforming or _shoot_timer.time_left > 0: return

	if AudioManager: AudioManager.play_bullet_sound(0, global_position)

	var base_angle = (pos - _gun.global_position).angle() + PI/2
	var angle = base_angle
	if _phase2_active:
		angle += randf_range(-0.25, 0.25)

	var bullet = _bullet_scene.instantiate()
	bullet.global_position = _bullet_position.global_position
	bullet.global_rotation = angle
	get_parent().add_child(bullet)

	# Дальность снаряда равна дальности атаки босса
	bullet.init(0, false, _damage, get_rid(), _attack_range)

	if _shot_flash: _shot_flash.play("Fire")
	_shoot_timer.start(_fire_rate)

const MINION_SEPARATION: float = 72.0

func _is_valid_spawn_position(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, pos)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	if not result.is_empty(): return false
	if not _is_clear_of_other_units(pos): return false
	return true

func _is_clear_of_other_units(pos: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node == self or node.is_queued_for_deletion(): continue
		if node.global_position.distance_squared_to(pos) < MINION_SEPARATION * MINION_SEPARATION: return false

	var space_state = get_world_2d().direct_space_state
	var shape = CircleShape2D.new(); shape.radius = 40.0
	var query = PhysicsShapeQueryParameters2D.new(); query.set_shape(shape); query.transform = Transform2D(0, pos); query.exclude = [self]
	var hits = space_state.intersect_shape(query)
	for hit in hits:
		if hit.collider is TileMap or hit.collider is StaticBody2D or hit.collider is CharacterBody2D: return false
	return true

func _get_valid_spawn_position() -> Vector2:
	var candidate = global_position + Vector2(randf_range(250, 400), 0).rotated(randf_range(0, TAU))
	_spawn_attempts = 0
	while not _is_valid_spawn_position(candidate) and _spawn_attempts < _max_spawn_attempts:
		candidate = global_position + Vector2(randf_range(220, 420), 0).rotated(randf_range(0, TAU))
		_spawn_attempts += 1
	return candidate

func _spawn_minion():
	if not is_instance_valid(_player): return
	_prune_minion_list()
	if _boss_minions.size() >= _max_minions: return

	var minion = _create_minion_instance()
	_boss_minions.append(minion)

func _spawn_independent_minion():
	if not is_instance_valid(_player): return
	_create_minion_instance()

func _create_minion_instance() -> Node:
	var minion = _enemy_scene.instantiate()
	var allowed_types = [TypeEnemy.LIGHT, TypeEnemy.MEDIUM, TypeEnemy.HEAVY]
	minion._type_enemy = allowed_types[randi() % allowed_types.size()]
	minion.global_position = _get_valid_spawn_position()
	get_parent().add_child(minion)
	if minion.has_method("_find_targets"): minion._find_targets()
	return minion
