extends Node2D

const LIFETIME: float = 7.0
const DAMAGE: int = 5
const TICK_INTERVAL: float = 1.0
const RADIUS: float = 16.0
const FLAMES: Array[Texture2D] = [
	preload("res://assets/future_tanks/SCML/Fire_Shots/Flame_A.png"),
	preload("res://assets/future_tanks/SCML/Fire_Shots/Flame_B.png"),
	preload("res://assets/future_tanks/SCML/Fire_Shots/Flame_C.png"),
	preload("res://assets/future_tanks/SCML/Fire_Shots/Flame_D.png"),
	preload("res://assets/future_tanks/SCML/Fire_Shots/Flame_E.png"),
	preload("res://assets/future_tanks/SCML/Fire_Shots/Flame_F.png"),
	preload("res://assets/future_tanks/SCML/Fire_Shots/Flame_G.png"),
	preload("res://assets/future_tanks/SCML/Fire_Shots/Flame_H.png"),
]

var _time: float = 0.0
var _segments: Array = []
var _hit_cooldowns: Dictionary = {}
var _hit_shape = CapsuleShape2D.new()
var _flame_frames: Array[Texture2D] = []

func _ready():
	top_level = true
	global_transform = Transform2D.IDENTITY
	z_index = -1
	for texture in FLAMES:
		var frame = AtlasTexture.new()
		frame.atlas = texture
		frame.region = texture.get_image().get_used_rect()
		_flame_frames.append(frame)
	set_physics_process(not _segments.is_empty())

func add_segment(from: Vector2, to: Vector2):
	_segments.append({"from": from, "to": to, "expires": _time + LIFETIME})
	set_physics_process(true)
	queue_redraw()

func _physics_process(delta: float):
	_time += delta
	_segments = _segments.filter(func(s): return s.expires > _time)
	for id in _hit_cooldowns.keys():
		if _hit_cooldowns[id] <= _time: _hit_cooldowns.erase(id)
	for player in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(player) or player.is_queued_for_deletion(): continue
		var id = player.get_instance_id()
		if _hit_cooldowns.has(id): continue
		var body_shape = player.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if body_shape == null or body_shape.disabled or body_shape.shape == null: continue
		for segment in _segments:
			if _overlaps_player(segment, body_shape):
				player.take_damage(DAMAGE)
				_hit_cooldowns[id] = _time + TICK_INTERVAL
				break
	queue_redraw()
	if _segments.is_empty() and _hit_cooldowns.is_empty(): set_physics_process(false)

func _overlaps_player(segment: Dictionary, body_shape: CollisionShape2D) -> bool:
	var from: Vector2 = segment.from
	var to: Vector2 = segment.to
	var closest = Geometry2D.get_closest_point_to_segment(body_shape.global_position, from, to)
	var body_scale = body_shape.global_scale.abs()
	var body_radius = body_shape.shape.get_rect().size.length() * maxf(body_scale.x, body_scale.y) * 0.5
	if closest.distance_to(body_shape.global_position) > body_radius + RADIUS: return false
	_hit_shape.radius = RADIUS
	_hit_shape.height = from.distance_to(to) + 2.0 * RADIUS
	return _hit_shape.collide(Transform2D((to - from).angle() + PI / 2, (from + to) * 0.5), body_shape.shape, body_shape.global_transform)

func _draw():
	for i in range(_segments.size()):
		var segment = _segments[i]
		var alpha = clampf((segment.expires - _time) / 0.8, 0.0, 1.0)
		var glow = Color(0.65, 0.06, 0.015, 0.35 * alpha)
		draw_line(segment.from, segment.to, glow, RADIUS * 1.6, true)
		draw_circle(segment.from, RADIUS * 0.8, glow)
		draw_circle(segment.to, RADIUS * 0.8, glow)
		var center: Vector2 = (segment.from + segment.to) * 0.5
		var flicker = 0.85 + 0.15 * sin(_time * 19.0 + i * 2.7)
		var size = Vector2(22, 34) * flicker
		var frame = _flame_frames[(floori(_time * 12.0) + i) % _flame_frames.size()]
		draw_texture_rect(frame, Rect2(center - size * 0.5, size), false, Color(1, 1, 1, alpha))
