extends KinematicBody2D
class_name Tank

# region protected fields
var _speed: int = 250
var _hp: int
var _isMoving: bool = false
var _velocity: Vector2 = Vector2.ZERO
var _bulletPosition: Position2D
var _shootTimer: Timer
var _gun: Sprite
var _tween: Tween
var _movingSound: AudioStreamPlayer
var _normalMovementVolume: float = 0.0
# endregion

var bulletScene: PackedScene

func _ready():
	_shootTimer = Timer.new()
	_shootTimer.wait_time = 1.0
	_shootTimer.one_shot = true
	add_child(_shootTimer)
	
	_tween = Tween.new()
	add_child(_tween)
	
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
			if _tween.is_active():
				_tween.stop_all()
				_tween.remove_all()
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
	if _tween.is_connected("tween_completed", self, "_on_tween_complete"):
		_tween.disconnect("tween_completed", self, "_on_tween_complete")
	if _tween.is_active():
		_tween.stop_all()
		_tween.remove_all()
	
	_tween.interpolate_property(
		_movingSound,
		"volume_db",
		_movingSound.volume_db,
		-80,
		0.3,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	)
	_tween.start()
	_tween.connect("tween_completed", self, "_on_tween_complete")

func _on_tween_complete(obj: Object, key: NodePath):
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
	
	var bullet = bulletScene.instance()
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
