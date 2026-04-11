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

const PLASMA: int = 0
const MEDIUM: int = 1
const LIGHT: int = 2

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
	if body is Player and not _is_player:
		body.take_damage(_damage)
		_destroy()
	elif body is Enemy and _is_player:
		body.take_damage(_damage)
		_destroy()
	elif body.has_method("can_bullet_pass"):
		if body.can_bullet_pass():
			return
		elif body.has_method("destroyable") and body.destroyable():
			body.destroy()
			_destroy()
		else:
			_destroy()
	elif body is Base:
		# Добавляем урон базе (если это база врага для игрока или наоборот)
		if body.has_method("take_damage"):
			# В Base.gd уже есть проверка в _on_bullet_entered,
			# но здесь мы просто уничтожаем пулю.
			# Урон нанесет сама база через свой сигнал area_entered.
			pass
		_destroy()
	elif body is StaticBody2D:
		_destroy()

func _destroy():
	queue_free()

func init(type_bullet: int, is_player: bool, damage: int = 0):
	_type_bullet = type_bullet
	_is_player = is_player
	_damage = damage # Всегда используем переданный урон

	_update_visuals_and_speed()

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

func _process(delta):
	_move()
