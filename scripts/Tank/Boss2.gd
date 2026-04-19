extends Enemy

const MAX_BOSS_MINIONS: int = 3
const PHASE2_HP_RATIO: float = 0.5
const MINION_SEPARATION: float = 72.0

var _spawn_timer: Timer
var _enemy_scene: PackedScene
var _ricochet_scene: PackedScene

var _hp_bar: ProgressBar
var _hp_bar_label: Label

var _boss_minions: Array = []
var _phase2_active: bool = false
var _is_transforming: bool = false

# Счётчики для спец-атак
var _bullet_count: int = 0
var _burst_count: int = 0

func _ready():
	_type_enemy = TypeEnemy.BOSS
	super._ready()
	_patrol_speed = 150
	_chase_speed = 130

	_notice_range = 1000.0
	_attack_range = 1000.0

	var collision = get_node_or_null("CollisionShape2D")
	if collision and collision.shape is CircleShape2D:
		collision.shape.radius *= 0.85

	if _body:
		_body.texture = load("res://assets/future_tanks/PNG/Hulls_Color_D/Hull_08.png")
		_body.modulate = Color(0.8, 0.25, 1.0)
	if _gun:
		_gun.texture = load("res://assets/future_tanks/PNG/Weapon_Color_D/Gun_02.png")
		_gun.modulate = Color(0.9, 0.4, 1.0)

	_setup_hp_bar()

	_enemy_scene = load("res://scenes/Tank/Enemy.tscn")
	_ricochet_scene = load("res://scenes/Tank/RicochetBullet.tscn")

func _setup_hp_bar():
	var canvas = CanvasLayer.new()
	add_child(canvas)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = _max_hp
	_hp_bar.value = _hp
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(520, 26)
	_hp_bar.anchor_left = 0.5; _hp_bar.anchor_right = 0.5; _hp_bar.anchor_top = 1.0; _hp_bar.anchor_bottom = 0.1
	_hp_bar.offset_left = -260.0; _hp_bar.offset_right = 260.0; _hp_bar.offset_top = 22.0; _hp_bar.offset_bottom = 50.0

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.07, 0.07, 0.4)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.65, 0.1, 0.9, 0.5)
	_hp_bar.add_theme_stylebox_override("background", bg)
	_set_bar_fill_color(Color(0.65, 0.0, 0.9, 0.6))
	canvas.add_child(_hp_bar)

	_hp_bar_label = Label.new()
	_hp_bar_label.text = "РИКОШЕТИР"
	_hp_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_bar_label.add_theme_color_override("font_color", Color(0.8, 0.5, 1.0, 0.7))
	_hp_bar_label.custom_minimum_size = Vector2(520, 20)
	_hp_bar_label.anchor_left = 0.5; _hp_bar_label.anchor_right = 0.5; _hp_bar_label.anchor_top = 1.0; _hp_bar_label.anchor_bottom = 0.1
	_hp_bar_label.offset_left = -260.0; _hp_bar_label.offset_right = 260.0; _hp_bar_label.offset_top = 0.0; _hp_bar_label.offset_bottom = 22.0
	canvas.add_child(_hp_bar_label)

func _set_bar_fill_color(color: Color):
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	if _hp_bar: _hp_bar.add_theme_stylebox_override("fill", fill)

func take_damage(damage: int):
	if _is_invulnerable: return
	super.take_damage(damage)
	if _hp_bar:
		_hp_bar.value = _hp

	if not _phase2_active and float(_hp) / float(_max_hp) <= PHASE2_HP_RATIO:
		_start_transformation()

func _play_body_hit_flash():
	if _body == null: return
	if _hit_flash_tween != null and _hit_flash_tween.is_running():
		_hit_flash_tween.kill()

	var base_color = Color(0.8, 0.25, 1.0) if not _phase2_active else Color(0.6, 0.05, 0.8)

	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(_body, "modulate", Color(4.5, 4.5, 4.5, 1.0), 0.05)
	_hit_flash_tween.tween_property(_body, "modulate", base_color, 0.07)

func _start_transformation():
	_phase2_active = true
	_is_transforming = true
	_is_invulnerable = true

	if _hp_bar_label:
		_hp_bar_label.text = "РИКОШЕТИР - ТРАНСФОРМАЦИЯ..."

	var duration = 2.5
	var shots = 15
	var angle_step = TAU / shots

	var tween = create_tween().set_parallel(true)
	if _gun:
		tween.tween_property(_gun, "rotation_degrees", 1080, duration).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)

	for i in range(shots):
		get_tree().create_timer(i * (duration/shots)).timeout.connect(func():
			if not is_instance_valid(self) or is_queued_for_deletion(): return
			_fire_burst(i * angle_step)
		)

	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self) and not is_queued_for_deletion():
		_finish_transformation()

func _fire_burst(angle: float):
	if AudioManager: AudioManager.play_bullet_sound(1, global_position)

	_burst_count += 1
	var is_exp_burst = (_burst_count % 3 == 0)

	var offsets = [-0.2, 0.2]
	for off in offsets:
		_spawn_boss_bullet(angle + off, 2, is_exp_burst)

func _finish_transformation():
	_is_transforming = false
	_is_invulnerable = false
	_fire_rate = 0.6
	_shoot_timer.wait_time = _fire_rate

	if _hp_bar_label:
		_hp_bar_label.text = "РИКОШЕТИР В ЯРОСТИ"
		_hp_bar_label.add_theme_color_override("font_color", Color(1.0, 0.4, 1.0, 0.8))

	if _body:
		var tween = create_tween().set_loops()
		tween.tween_property(_body, "modulate", Color(1.5, 0.1, 1.5), 0.3)
		tween.tween_property(_body, "modulate", Color(0.6, 0.05, 0.8), 0.3)

func _fire_at_pos(pos: Vector2):
	if _is_transforming or _shoot_timer.time_left > 0 or _ricochet_scene == null:
		return

	if AudioManager:
		AudioManager.play_bullet_sound(1, global_position)

	var base_angle: float = (pos - _gun.global_position).angle() + PI * 0.5
	var bounces = 2 if _phase2_active else 1
	var spread = randf_range(-0.2, 0.2) if _phase2_active else 0.0

	if not _phase2_active:
		_bullet_count += 1
		var is_exp = (_bullet_count % 3 == 0)
		_spawn_boss_bullet(base_angle + spread, bounces, is_exp)
	else:
		_burst_count += 1
		var is_exp_burst = (_burst_count % 3 == 0)
		var offsets = [-0.15, 0.15]
		for off in offsets:
			_spawn_boss_bullet(base_angle + off + spread, bounces, is_exp_burst)

	if _shot_flash:
		_shot_flash.play("Fire")
	_shoot_timer.start()

func _spawn_boss_bullet(angle: float, bounces_val: int, explosive: bool):
	var bullet = _ricochet_scene.instantiate()
	bullet.global_position = _bullet_position.global_position
	bullet.global_rotation = angle
	get_parent().add_child(bullet)
	bullet.init(false, _damage, int(_damage * 1.8), get_rid(), bounces_val, explosive)

func _prune_minion_list():
	_boss_minions = _boss_minions.filter(func(n): return is_instance_valid(n) and not n.is_queued_for_deletion())

func _spawn_minion():
	if not is_instance_valid(_player) or not is_instance_valid(self): return
	_prune_minion_list()
	if _boss_minions.size() >= MAX_BOSS_MINIONS: return

	var minion = _enemy_scene.instantiate()
	var allowed = [TypeEnemy.LIGHT, TypeEnemy.MEDIUM, TypeEnemy.HEAVY]
	minion._type_enemy = allowed[randi() % allowed.size()]
	minion.global_position = _get_valid_spawn_position()
	get_parent().add_child(minion)
	_boss_minions.append(minion)
	if minion.has_method("_find_targets"): minion._find_targets()

func _get_valid_spawn_position() -> Vector2:
	var candidate := global_position + Vector2(randf_range(250.0, 400.0), 0.0).rotated(randf_range(0.0, TAU))
	for _i in range(28):
		if _is_valid_spawn_pos(candidate): return candidate
		candidate = global_position + Vector2(randf_range(220.0, 420.0), 0.0).rotated(randf_range(0.0, TAU))
	return global_position

func _is_valid_spawn_pos(pos: Vector2) -> bool:
	var space = get_world_2d().direct_space_state
	var ray = PhysicsRayQueryParameters2D.create(global_position, pos)
	ray.exclude = [self]
	if not space.intersect_ray(ray).is_empty(): return false
	var shape = CircleShape2D.new(); shape.radius = 42.0
	var query = PhysicsShapeQueryParameters2D.new(); query.set_shape(shape); query.transform = Transform2D(0.0, pos); query.exclude = [self]
	for hit in space.intersect_shape(query):
		if hit.collider is TileMap or hit.collider is StaticBody2D or hit.collider is CharacterBody2D: return false
	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e != self and not e.is_queued_for_deletion():
			if e.global_position.distance_squared_to(pos) < MINION_SEPARATION * MINION_SEPARATION: return false
	return true
