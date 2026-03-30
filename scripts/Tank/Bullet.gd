extends Area2D

# region private fields
var _bullet_speed: int = 7
var _velocity: Vector2 = Vector2.ZERO
var _bullet_sound: AudioStreamPlayer
var _tween_bullet: Tween
var _visibility_bullet: VisibilityNotifier2D
var _type_bullet: int
var _bullet_sprite: Sprite
var _damage: int = 0
var _is_player: bool = false
# endregion

const PLASMA: int = 0
const MEDIUM: int = 1
const LIGHT: int = 2

func get_bullet_speed() -> int:
	return _bullet_speed

func set_bullet_speed(value: int) -> void:
	if value > 0 and value <= 30:
		_bullet_speed = value

func is_player() -> bool:
	return _is_player

func _ready():
	_bullet_sprite = $BulletSprite
	_bullet_sound = $PlasmaGunSound
	_velocity = Vector2(0, -1).rotated(rotation)
	_visibility_bullet = $VisibilityNotifier2D
	_tween_bullet = Tween.new()
	add_child(_tween_bullet)

	connect("body_entered", self, "_on_body_entered")
	if not _visibility_bullet.is_connected("screen_exited", self, "_on_screen_exited"):
		_visibility_bullet.connect("screen_exited", self, "_on_screen_exited")

func _move():
	position += _velocity * _bullet_speed

func _fade_sound():
	if _tween_bullet == null:
		return
	if not _tween_bullet.is_inside_tree():
		queue_free()
		return
	if _tween_bullet.is_connected("tween_completed", self, "_on_tween_complete"):
		_tween_bullet.disconnect("tween_completed", self, "_on_tween_complete")
	_tween_bullet.interpolate_property(
		_bullet_sound,
		"volume_db",
		_bullet_sound.volume_db,
		-80,
		1.0,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	)
	_tween_bullet.start()
	_tween_bullet.connect("tween_completed", self, "_on_tween_complete")

func _on_tween_complete(_obj, _key):
	_bullet_sound.stop()
	_bullet_sound.volume_db = 0
	queue_free()

func _on_screen_exited():
	_fade_sound()

func _on_body_entered(body):
	# Проверяем через get_script() вместо class_name
	var script_path = body.get_script().resource_path if body.get_script() != null else ""
	
	if script_path.find("Player.gd") != -1 and not _is_player:
		body.take_damage(_damage)
		_destroy()
	elif script_path.find("Enemy.gd") != -1 and _is_player:
		body.take_damage(_damage)
		_destroy()
	elif script_path.find("IngameWall.gd") != -1:
		if body.can_bullet_pass():
			return
		elif body.destroyable():
			body.destroy()
			_destroy()
		else:
			_destroy()
	elif script_path.find("Base.gd") != -1:
		_destroy()
	elif body is StaticBody2D:
		_destroy()

func _destroy():
	queue_free()

func init(type_bullet: int, is_player: bool, damage: int = 0):
	_type_bullet = type_bullet
	_is_player = is_player
	
	if is_player:
		_update_type()
	else:
		_damage = damage
		_update_appearance()

func _update_type():
	match _type_bullet:
		PLASMA:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Plasma.png")
			_bullet_speed = 7
			_damage = 25
		MEDIUM:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Medium_Shell.png")
			_bullet_speed = 4
			_damage = 40
		LIGHT:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Light_Shell.png")
			_bullet_speed = 6
			_damage = 35

	if AudioManager != null:
		AudioManager.play_bullet_sound(_type_bullet, global_position)

func _update_appearance():
	match _type_bullet:
		PLASMA:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Plasma.png")
			_bullet_speed = 7
		MEDIUM:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Medium_Shell.png")
			_bullet_speed = 4
		LIGHT:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Light_Shell.png")
			_bullet_speed = 6

	if AudioManager != null:
		AudioManager.play_bullet_sound(_type_bullet, global_position)

func _process(delta):
	_move()
