extends CharacterBody2D
class_name Tank

# region protected fields
var _speed: int = 250
var _hp: int
var _isMoving: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _bulletPosition: Marker2D
var _shootTimer: Timer
var _gun: Sprite2D
var _movingSound: AudioStreamPlayer
var _normalMovementVolume: float = 0.0
# endregion

var bulletScene: PackedScene

func _ready():
	_shootTimer = Timer.new()
	_shootTimer.wait_time = 1.0
	_shootTimer.one_shot = true
	add_child(_shootTimer)

	_bulletPosition = get_node("BodyTank/Gun/BulletPosition")
	_gun = get_node("BodyTank/Gun")
	_movingSound = get_node("MovingSound")
	
	_configure_audio()
	if _movingSound != null:
		_normalMovementVolume = _movingSound.volume_db

func _configure_audio():
	if _movingSound != null:
		_movingSound.bus = "SFX"

func _handle_movement_sound(movementVelocity: Vector2):
	var isMovingNow = movementVelocity.length() > 0.1
	
	if isMovingNow:
		if not _isMoving:
			# Убрали создание пустого Tween тут
			if _movingSound != null:
				_movingSound.volume_db = _normalMovementVolume
				if not _movingSound.playing:
					_movingSound.play()
			_isMoving = true
	else:
		if _isMoving:
			_isMoving = false
			if _movingSound != null and _movingSound.playing:
				_fade_sound()

func _fade_sound():
	# Создаем Tween только при необходимости
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_LINEAR)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_movingSound, "volume_db", -80.0, 0.3)
	tween.finished.connect(_on_tween_complete)

func _on_tween_complete():
	if _movingSound != null:
		_movingSound.stop()
		_movingSound.volume_db = _normalMovementVolume

func _rotate_gun_toward(targetGlobalPosition: Vector2):
	if _gun == null:
		return
	
	var directionToTarget = (targetGlobalPosition - _gun.global_position).normalized()
	var targetAngle = directionToTarget.angle()
	_gun.global_rotation = targetAngle + PI / 2

func _fire_bullet(type: int, isPlayer: bool):
	if _shootTimer.time_left > 0:
		return
	
	var bullet = bulletScene.instantiate()
	bullet.global_position = _bulletPosition.global_position
	bullet.global_rotation = _gun.global_rotation
	get_tree().root.add_child(bullet)
	bullet.init(type, isPlayer, 20)
	_shootTimer.start()

func take_damage(damage: int):
	_hp -= damage
	if _hp <= 0:
		_destroy()

func _destroy():
	queue_free()
