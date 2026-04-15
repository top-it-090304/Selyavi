extends Area2D

var _bullet_speed: int = 7
var _velocity: Vector2 = Vector2.ZERO
var _bullet_sound: AudioStreamPlayer
var _visibility_bullet: VisibleOnScreenNotifier2D
var _type_bullet: int
var _bullet_sprite: Sprite2D
var _damage: int = 0
var _is_player: bool = false
var _traveled_distance: float = 0.0
var _max_range: float = 1000.0
var _ignored_body_rid: RID # RID тела, которое пуля игнорирует (например, стрелявшая база)
var _pierce_left: int = 0
var _aoe_radius: float = 0.0
var _aoe_damage_multiplier: float = 0.0

const PLASMA: int = 0
const MEDIUM: int = 1
const LIGHT: int = 2
const HE: int = 3
const BOPS: int = 4

func get_bullet_speed() -> int:
	return _bullet_speed

func set_bullet_speed(value: int):
	if value > 0 and value <= 30:
		_bullet_speed = value

func is_player() -> bool:
	return _is_player

func _ready():
	_bullet_sprite = $BulletSprite
	_bullet_sound = $PlasmaGunSound
	_velocity = Vector2(0, -1).rotated(rotation)
	_visibility_bullet = $VisibleOnScreenNotifier2D
	
	body_entered.connect(_on_body_entered)
	if not _visibility_bullet.is_connected("screen_exited", _on_screen_exited):
		_visibility_bullet.screen_exited.connect(_on_screen_exited)

func _move():
	var move_step = _velocity * _bullet_speed
	position += move_step
	_traveled_distance += move_step.length()

	if _traveled_distance >= _max_range:
		_destroy()

func _fade_sound():
	var tween = create_tween()
	tween.tween_property(_bullet_sound, "volume_db", -80, 1.0)
	tween.finished.connect(_on_fade_complete)

func _on_fade_complete():
	if _bullet_sound != null:
		_bullet_sound.stop()
		_bullet_sound.volume_db = 0
	queue_free()

func _on_screen_exited():
	_fade_sound()

func _on_body_entered(body):
	# Игнорируем тело стрелка (базу или танк), если задан RID
	if _ignored_body_rid.is_valid() and body.get_rid() == _ignored_body_rid:
		return

	if body is Player and not _is_player:
		body.take_damage(_damage)
		_post_hit_destroy(body)
	elif body is Enemy and _is_player:
		body.take_damage(_damage)
		if _type_bullet == BOPS and _pierce_left > 0:
			_pierce_left -= 1
		else:
			_post_hit_destroy(body)
	elif body.has_method("can_bullet_pass"):
		if body.can_bullet_pass():
			return
		elif body.has_method("destroyable") and body.destroyable():
			body.destroy()
			_post_hit_destroy(body)
		else:
			_post_hit_destroy(body)
	elif body is Base:
		_post_hit_destroy(body)
	elif body is StaticBody2D:
		_post_hit_destroy(body)

func _post_hit_destroy(hit_body: Node):
	if _is_player and _type_bullet == HE and _aoe_radius > 0.0:
		_apply_aoe_damage(hit_body)
	_destroy()

func _destroy():
	queue_free()

func init(type_bullet: int, is_player: bool, damage: int = 0, ignored_rid: RID = RID(), custom_range: float = -1.0):
	_type_bullet = type_bullet
	_is_player = is_player
	_damage = damage
	_ignored_body_rid = ignored_rid

	_update_visuals_and_speed()

	# Теперь дальность устанавливается либо стандартно (в _update_visuals_and_speed),
	# либо принудительно, если передано значение больше 0 (для штаба)
	if custom_range > 0:
		_max_range = custom_range

func _update_visuals_and_speed():
	match _type_bullet:
		PLASMA:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Plasma.png")
			_bullet_speed = 7
			_max_range = 600.0
		MEDIUM:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Medium_Shell.png")
			_bullet_speed = 4
			_max_range = 275.0
		LIGHT:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Light_Shell.png")
			_bullet_speed = 6
			_max_range = 900.0
		HE:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Granade_Shell.png")
			_bullet_speed = 5
			_max_range = 520.0
			_aoe_radius = 105.0
			_aoe_damage_multiplier = 0.65
		BOPS:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Heavy_Shell.png")
			_bullet_speed = 9
			_max_range = 1000.0
			_pierce_left = 2

func _apply_aoe_damage(hit_body: Node):
	var space_state = get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = _aoe_radius
	var query = PhysicsShapeQueryParameters2D.new()
	query.set_shape(shape)
	query.transform = Transform2D(0.0, global_position)
	query.exclude = [get_rid()]
	if _ignored_body_rid.is_valid():
		query.exclude.append(_ignored_body_rid)

	var splash_damage = int(float(_damage) * _aoe_damage_multiplier)
	var results = space_state.intersect_shape(query, 24)
	for result in results:
		var c = result.collider
		if c == hit_body:
			continue
		if c is Enemy and _is_player:
			c.take_damage(splash_damage)
		elif c is Player and not _is_player:
			c.take_damage(splash_damage)

func _process(delta):
	_move()
