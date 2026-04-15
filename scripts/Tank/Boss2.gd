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

func _ready():
	_type_enemy = TypeEnemy.BOSS
	super._ready()

	if _body:
		_body.texture = load("res://assets/future_tanks/PNG/Hulls_Color_D/Hull_07.png")
		_body.modulate = Color(0.8, 0.25, 1.0)
	if _gun:
		_gun.modulate = Color(0.9, 0.4, 1.0)

	_setup_hp_bar()

	_enemy_scene = load("res://scenes/Tank/Enemy.tscn")
	_ricochet_scene = load("res://scenes/Tank/RicochetBullet.tscn")

	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = 9.0
	_spawn_timer.autostart = true
	_spawn_timer.timeout.connect(_spawn_minion)
	add_child(_spawn_timer)

func _setup_hp_bar():
	var canvas = CanvasLayer.new()
	add_child(canvas)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = _max_hp
	_hp_bar.value = _hp
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(520, 26)
	_hp_bar.anchor_left = 0.5
	_hp_bar.anchor_right = 0.5
	_hp_bar.anchor_top = 1.0
	_hp_bar.anchor_bottom = 0.1
	_hp_bar.offset_left = -260.0
	_hp_bar.offset_right = 260.0
	_hp_bar.offset_top = 22.0
	_hp_bar.offset_bottom = 50.0

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.07, 0.07, 0.78)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.65, 0.1, 0.9, 1.0)
	_hp_bar.add_theme_stylebox_override("background", bg)
	_set_bar_fill_color(Color(0.65, 0.0, 0.9, 0.95))
	canvas.add_child(_hp_bar)

	_hp_bar_label = Label.new()
	_hp_bar_label.text = "RICOCHET BOSS"
	_hp_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_bar_label.add_theme_color_override("font_color", Color(0.9, 0.55, 1.0))
	_hp_bar_label.custom_minimum_size = Vector2(520, 20)
	_hp_bar_label.anchor_left = 0.5
	_hp_bar_label.anchor_right = 0.5
	_hp_bar_label.anchor_top = 1.0
	_hp_bar_label.anchor_bottom = 0.1
	_hp_bar_label.offset_left = -260.0
	_hp_bar_label.offset_right = 260.0
	_hp_bar_label.offset_top = 0.0
	_hp_bar_label.offset_bottom = 22.0
	canvas.add_child(_hp_bar_label)

func _set_bar_fill_color(color: Color):
	var fill = StyleBoxFlat.new()
	fill.bg_color = color
	if _hp_bar:
		_hp_bar.add_theme_stylebox_override("fill", fill)

func take_damage(damage: int):
	super.take_damage(damage)
	if _hp_bar:
		_hp_bar.value = _hp
	if not _phase2_active and float(_hp) / float(_max_hp) <= PHASE2_HP_RATIO:
		_activate_phase2()

func _activate_phase2():
	_phase2_active = true
	_fire_rate = 0.55
	_shoot_timer.wait_time = _fire_rate

	if _body:
		var tween = create_tween().set_loops()
		tween.tween_property(_body, "modulate", Color(1.5, 0.1, 1.5), 0.35)
		tween.tween_property(_body, "modulate", Color(0.6, 0.05, 0.8), 0.35)

	_set_bar_fill_color(Color(1.0, 0.05, 0.35, 0.95))
	if _hp_bar_label:
		_hp_bar_label.text = "RICOCHET BOSS - PHASE II"
		_hp_bar_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.25))

func _fire_at_pos(pos: Vector2):
	if _shoot_timer.time_left > 0 or _ricochet_scene == null:
		return
	if AudioManager:
		AudioManager.play_bullet_sound(0, global_position)

	var base_angle: float = (pos - _gun.global_position).angle() + PI * 0.5
	var offsets: Array = [0.0]
	if _phase2_active:
		offsets = [-0.38, 0.0, 0.38]

	for offset_angle in offsets:
		var bullet = _ricochet_scene.instantiate()
		bullet.global_position = _bullet_position.global_position
		bullet.global_rotation = base_angle + offset_angle
		get_parent().add_child(bullet)
		bullet.init(false, _damage, int(_damage * 1.6))

	if _shot_flash:
		_shot_flash.play("Fire")
	_shoot_timer.start()

func _prune_minion_list():
	_boss_minions = _boss_minions.filter(
		func(n): return is_instance_valid(n) and not n.is_queued_for_deletion()
	)

func _spawn_minion():
	if not is_instance_valid(_player):
		return
	_prune_minion_list()
	if _boss_minions.size() >= MAX_BOSS_MINIONS:
		return

	var minion = _enemy_scene.instantiate()
	var allowed = [TypeEnemy.LIGHT, TypeEnemy.MEDIUM, TypeEnemy.HEAVY]
	minion._type_enemy = allowed[randi() % allowed.size()]
	minion.global_position = _get_valid_spawn_position()
	get_parent().add_child(minion)
	_boss_minions.append(minion)
	if minion.has_method("_find_targets"):
		minion._find_targets()

func _get_valid_spawn_position() -> Vector2:
	var candidate := global_position + Vector2(randf_range(250.0, 400.0), 0.0).rotated(randf_range(0.0, TAU))
	for _i in range(28):
		if _is_valid_spawn_pos(candidate):
			return candidate
		candidate = global_position + Vector2(randf_range(220.0, 420.0), 0.0).rotated(randf_range(0.0, TAU))
	return global_position

func _is_valid_spawn_pos(pos: Vector2) -> bool:
	var space = get_world_2d().direct_space_state
	var ray = PhysicsRayQueryParameters2D.create(global_position, pos)
	ray.exclude = [self]
	if not space.intersect_ray(ray).is_empty():
		return false

	var shape = CircleShape2D.new()
	shape.radius = 42.0
	var query = PhysicsShapeQueryParameters2D.new()
	query.set_shape(shape)
	query.transform = Transform2D(0.0, pos)
	query.exclude = [self]
	for hit in space.intersect_shape(query):
		var c = hit.collider
		if c is TileMap or c is StaticBody2D or c is CharacterBody2D:
			return false

	for e in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(e) and e != self and not e.is_queued_for_deletion():
			if e.global_position.distance_squared_to(pos) < MINION_SEPARATION * MINION_SEPARATION:
				return false
	return true
