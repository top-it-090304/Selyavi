extends StaticBody2D

const MAX_HP: int = 60
const FLIGHT_SPEED: float = 420.0
const LIFETIME: float = 20.0
const AURA_RADIUS: float = 160.0
const AURA_DAMAGE: int = 15
const HIT_INTERVAL: float = 1.0

var emitter: Node2D
var target_position: Vector2
var _hp: int = MAX_HP
var _deployed: bool = false
var _life_left: float = LIFETIME
var _hit_cooldown: float = 0.0
var _flight_excluded: Array[RID] = []
var _shape: CircleShape2D
var _aura_shape: CircleShape2D

func _ready():
	add_to_group("enemy_installations")
	collision_layer = 32
	collision_mask = 0
	_shape = $CollisionShape2D.shape
	_aura_shape = CircleShape2D.new()
	_aura_shape.radius = AURA_RADIUS
	_flight_excluded = [get_rid()]
	for group in ["players", "enemies"]:
		for body in get_tree().get_nodes_in_group(group):
			if body is PhysicsBody2D: _flight_excluded.append(body.get_rid())
	# У стены дульная точка может быть слишком тесной для установки.
	var query = _flight_query()
	if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty() and is_instance_valid(emitter):
		global_position = emitter.global_position

func _flight_query() -> PhysicsShapeQueryParameters2D:
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = _shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 1
	query.exclude = _flight_excluded
	query.margin = 0.1
	return query

func _physics_process(delta: float):
	if not _deployed:
		var offset = target_position - global_position
		var motion = offset.normalized() * minf(offset.length(), FLIGHT_SPEED * delta)
		var query = _flight_query()
		query.motion = motion
		var safe_fraction = get_world_2d().direct_space_state.cast_motion(query)[0]
		global_position += motion * safe_fraction
		if safe_fraction < 0.99999 or global_position.distance_to(target_position) <= 0.1:
			_deployed = true
			queue_redraw()
		return
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()
		return
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	if _hit_cooldown > 0.0: return
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = _aura_shape
	query.transform = Transform2D(0.0, global_position)
	query.collision_mask = 1
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 64):
		if hit.collider is Player and not hit.collider.is_queued_for_deletion():
			hit.collider.take_damage(AURA_DAMAGE)
			_hit_cooldown = HIT_INTERVAL
			break

func take_damage(damage: int):
	if _hp <= 0 or is_queued_for_deletion(): return
	_hp -= damage
	if _hp <= 0:
		queue_free()
	else:
		var visual = $Visual
		visual.modulate = Color(2, 2, 2)
		visual.create_tween().tween_property(visual, "modulate", Color.WHITE, 0.15)

func _draw():
	if not _deployed: return
	draw_circle(Vector2.ZERO, AURA_RADIUS, Color(1.0, 0.85, 0.05, 0.08))
	draw_arc(Vector2.ZERO, AURA_RADIUS, 0, TAU, 96, Color(1.0, 0.85, 0.1, 0.85), 4.0, true)
