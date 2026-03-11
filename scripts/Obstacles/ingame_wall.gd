extends StaticBody2D
class_name IngameWall

var _destroyable: bool
var _can_player_pass: bool
var _player_speed: int
var _can_bullet_pass: bool

func destroy():
	if _destroyable:
		queue_free()

func destroyable() -> bool:
	return _destroyable

func can_player_pass() -> bool:
	return _can_player_pass

func player_speed() -> int:
	return _player_speed

func can_bullet_pass() -> bool:
	return _can_bullet_pass

func _init(destroyable: bool = false, can_player_pass: bool = false, player_speed: int = 0, can_bullet_pass: bool = false):
	_destroyable = destroyable
	_can_player_pass = can_player_pass
	_player_speed = player_speed
	_can_bullet_pass = can_bullet_pass
