extends StaticBody2D

const COLLISION_LAYER: int = 16
const START_RADIUS: float = 14.0
const FINAL_RADIUS: float = 64.0
const SPEED: float = 350.0
const HOLD_TIME: float = 5.0
const FADE_TIME: float = 1.0

var direction: Vector2 = Vector2.RIGHT
var travel_distance: float = 300.0
var hits_left: int = 3
var _traveled: float = 0.0
var _hover_time: float = 0.0
var _radius: float = START_RADIUS
var _wall_cast: ShapeCast2D
var _points: PackedVector2Array
var _reflected_projectiles: Dictionary = {}

func _ready():
	collision_layer = COLLISION_LAYER
	collision_mask = 0
	for i in range(25):
		var angle = -PI / 2 + PI * i / 24.0
		_points.append(Vector2(cos(angle), sin(angle)))
	var polygon = ConvexPolygonShape2D.new()
	polygon.points = _points
	var shape = CollisionShape2D.new()
	shape.shape = polygon
	add_child(shape)
	_wall_cast = ShapeCast2D.new()
	_wall_cast.enabled = false
	_wall_cast.visible = false
	_wall_cast.top_level = true
	_wall_cast.shape = polygon
	_wall_cast.collision_mask = 1
	_wall_cast.collide_with_areas = false
	_wall_cast.max_results = 64
	add_child(_wall_cast)
	global_rotation = direction.angle()
	global_scale = Vector2.ONE * _radius

func _physics_process(delta: float):
	var motion = Vector2.ZERO
	var next_radius = _radius
	if _traveled < travel_distance:
		var step = minf(SPEED * delta, travel_distance - _traveled)
		motion = direction * step
		next_radius = lerpf(START_RADIUS, FINAL_RADIUS, smoothstep(0.0, 1.0, (_traveled + step) / maxf(travel_distance, 0.001)))
	if _hits_solid_wall(next_radius, motion):
		queue_free()
		return
	if not motion.is_zero_approx():
		global_position += motion
		_traveled += motion.length()
		_radius = next_radius
		global_scale = Vector2.ONE * _radius
		queue_redraw()
	else:
		_hover_time += delta
		if _hover_time > HOLD_TIME:
			modulate.a = clampf(1.0 - (_hover_time - HOLD_TIME) / FADE_TIME, 0.0, 1.0)
			if _hover_time >= HOLD_TIME + FADE_TIME: queue_free()

func _hits_solid_wall(radius: float, motion: Vector2) -> bool:
	_wall_cast.global_transform = Transform2D(direction.angle(), Vector2.ONE * radius, 0.0, global_position)
	_wall_cast.target_position = _wall_cast.to_local(global_position + motion)
	_wall_cast.clear_exceptions()
	_wall_cast.add_exception(self)
	for attempt in range(64):
		_wall_cast.force_shapecast_update()
		if not _wall_cast.is_colliding(): return false
		var skipped = false
		for i in range(_wall_cast.get_collision_count()):
			var collider = _wall_cast.get_collider(i)
			if collider is CharacterBody2D or (collider is Node and collider.has_method("destroyable") and collider.destroyable()):
				_wall_cast.add_exception_rid(_wall_cast.get_collider_rid(i))
				skipped = true
			else:
				return true
		if not skipped: return true
	return true

func reflect_player_projectile(projectile, impact: Vector2, normal: Vector2) -> bool:
	if hits_left <= 0 or not projectile.has_method("is_player") or not projectile.is_player(): return false
	var id = projectile.get_instance_id()
	if _reflected_projectiles.has(id): return false
	_reflected_projectiles[id] = true
	projectile.reflect_from_shield(normal.normalized(), impact, get_rid())
	hits_left -= 1
	if hits_left <= 0: queue_free()
	return true

func surface_normal(point: Vector2) -> Vector2:
	var local = to_local(point)
	var normal = Vector2.LEFT if absf(local.x) < absf(local.length() - 1.0) else local.normalized()
	return global_transform.basis_xform(normal).normalized()

func _draw():
	draw_colored_polygon(_points, Color(0.1, 0.55, 1.0, 0.16))
	draw_polyline(_points, Color(0.3, 0.8, 1.0, 0.95), 4.0 / _radius, true)
	draw_line(_points[0], _points[_points.size() - 1], Color(0.3, 0.8, 1.0, 0.3), 2.0 / _radius, true)
