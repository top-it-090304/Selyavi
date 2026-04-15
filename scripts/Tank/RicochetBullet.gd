extends Area2D

# --- ????????? ---
const BULLET_SPEED: float = 8.0
const MAX_RANGE: float = 2200.0
const SPLASH_RADIUS: float = 115.0
const DEFAULT_BOUNCES: int = 3

# --- ????????? ---
var _velocity: Vector2 = Vector2.ZERO        # ??????????????? ?????? ???????????
var _damage: int = 30
var _splash_damage: int = 50
var _is_player: bool = false
var _bounces_left: int = DEFAULT_BOUNCES
var _traveled_distance: float = 0.0
var _ignored_body_rid: RID
var _destroyed: bool = false

var _bullet_sprite: Sprite2D

# ---------- API ----------

func is_player() -> bool:
	return _is_player

## ?????????? ????? ????? add_child (rotation ??? ??????????)
func init(is_player: bool, damage: int, splash_damage: int,
		ignored_rid: RID = RID(), bounces: int = DEFAULT_BOUNCES):
	_is_player = is_player
	_damage = damage
	_splash_damage = splash_damage
	_ignored_body_rid = ignored_rid
	_bounces_left = bounces

# ---------- Lifecycle ----------

func _ready():
	_bullet_sprite = get_node_or_null("BulletSprite")
	_velocity = Vector2(0.0, -1.0).rotated(rotation)
	body_entered.connect(_on_body_entered)

func _process(_delta):
	if _destroyed:
		return
	_move()

# ---------- ???????? ? ????????? ----------

func _move():
	var dir: Vector2 = _velocity.normalized()
	var step: Vector2 = dir * BULLET_SPEED

	# ???????????? ???????: ???? ?????? ?? ???? ????? ?????????, ????? ???????? ???????
	var space_state = get_world_2d().direct_space_state
	var ray = PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + dir * (BULLET_SPEED + 14.0)
	)
	ray.exclude = [get_rid()]
	if _ignored_body_rid.is_valid():
		ray.exclude.append(_ignored_body_rid)

	var hit = space_state.intersect_ray(ray)

	if hit:
		var collider = hit.collider

		# ?????? ????????? ? ????
		if collider is Player and not _is_player:
			collider.take_damage(_damage)
			_explode()
			return
		elif collider is Enemy and _is_player:
			collider.take_damage(_damage)
			_explode()
			return
		# ????? / ??????????? ? ???????
		elif _is_wall(collider):
			if _bounces_left > 0:
				_velocity = _velocity.bounce(hit.normal)
				rotation = _velocity.angle() + PI * 0.5
				_bounces_left -= 1
				# ?????????? ???? ?? ?????, ????? ?? ????????
				global_position = hit.position + hit.normal * 5.0
				_play_ricochet_fx()
			else:
				global_position = hit.position
				_explode()
			return

	# ??????? ????????
	global_position += step
	_traveled_distance += BULLET_SPEED
	if _traveled_distance >= MAX_RANGE:
		_explode()

func _is_wall(collider: Object) -> bool:
	if collider == null:
		return false
	if collider is Player or collider is Enemy:
		return false
	if collider is StaticBody2D:
		return true
	if collider.has_method("can_bullet_pass"):
		return not collider.can_bullet_pass()
	var cls: String = collider.get_class()
	if cls == "TileMap" or cls == "TileMapLayer":
		return true
	return false

# ---------- ???????? (???????? ??????? ??? ??????/?????) ----------

func _on_body_entered(body):
	if _destroyed:
		return
	if _ignored_body_rid.is_valid() and body.get_rid() == _ignored_body_rid:
		return
	if body is Player and not _is_player:
		body.take_damage(_damage)
		_explode()
	elif body is Enemy and _is_player:
		body.take_damage(_damage)
		_explode()
	# ????? ?????????????? ?????????; ????? ?? ??????????, ????? ?? ?????????? ??????

# ---------- ????? ----------

func _explode():
	if _destroyed:
		return
	_destroyed = true

	# ?????-???? ? ???????
	var space_state = get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = SPLASH_RADIUS
	var query = PhysicsShapeQueryParameters2D.new()
	query.set_shape(shape)
	query.transform = Transform2D(0.0, global_position)
	var results = space_state.intersect_shape(query, 20)

	for result in results:
		var c = result.collider
		if c is Player and not _is_player:
			c.take_damage(_splash_damage)
		elif c is Enemy and _is_player:
			c.take_damage(_splash_damage)

	_spawn_explosion_fx()
	queue_free()

# ---------- ??????? ----------

func _play_ricochet_fx():
	# ????????????? ????? ??? ???????
	var sparks = CPUParticles2D.new()
	sparks.global_position = global_position
	sparks.emitting = true
	sparks.one_shot = true
	sparks.amount = 10
	sparks.lifetime = 0.22
	sparks.explosiveness = 1.0
	sparks.spread = 70.0
	sparks.initial_velocity_min = 90.0
	sparks.initial_velocity_max = 200.0
	sparks.scale_amount_min = 0.12
	sparks.scale_amount_max = 0.30
	sparks.color = Color(1.0, 0.8, 0.2, 1.0)
	get_parent().add_child(sparks)
	get_tree().create_timer(1.0).timeout.connect(
		func(): if is_instance_valid(sparks): sparks.queue_free()
	)

	# ???? ????????
	var snd = AudioStreamPlayer2D.new()
	snd.stream = load("res://assets/sounds/light_bullet.mp3")
	snd.volume_db = -4.0
	snd.pitch_scale = randf_range(1.2, 1.6)
	snd.bus = "SFX"
	get_parent().add_child(snd)
	snd.global_position = global_position
	snd.play()
	snd.finished.connect(func(): snd.queue_free())

func _spawn_explosion_fx():
	# ???????? ?????? ??????
	var expl = CPUParticles2D.new()
	expl.global_position = global_position
	expl.emitting = true
	expl.one_shot = true
	expl.amount = 40
	expl.lifetime = 0.75
	expl.explosiveness = 0.95
	expl.spread = 180.0
	expl.initial_velocity_min = 130.0
	expl.initial_velocity_max = 340.0
	expl.scale_amount_min = 0.45
	expl.scale_amount_max = 1.1
	expl.gravity = Vector2(0.0, -50.0)
	var grad = Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.3, 1.0))
	grad.add_point(0.25, Color(1.0, 0.4, 0.0, 0.95))
	grad.add_point(0.6, Color(0.7, 0.1, 0.0, 0.6))
	grad.add_point(1.0, Color(0.15, 0.15, 0.15, 0.0))
	expl.color_ramp = grad
	get_parent().add_child(expl)
	get_tree().create_timer(2.0).timeout.connect(
		func(): if is_instance_valid(expl): expl.queue_free()
	)

	# ???? ??????
	var snd = AudioStreamPlayer2D.new()
	snd.stream = load("res://assets/sounds/vystrel-tanka.mp3")
	snd.volume_db = 3.0
	snd.pitch_scale = 0.55
	snd.bus = "SFX"
	get_parent().add_child(snd)
	snd.global_position = global_position
	snd.play()
	snd.finished.connect(func(): snd.queue_free())
