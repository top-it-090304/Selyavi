class_name IngameWall
extends StaticBody2D

var _destroyable: bool = false
var _can_player_pass: bool = false
var _player_speed: int = 0
var _can_bullet_pass: bool = false
var _hp: int = 50 # Здоровье стены

func take_damage(damage: int):
	if _destroyable:
		_hp -= damage
		if _hp <= 0:
			destroy()

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

# Используем метод init для инициализации
func init(destroyable: bool, can_player_pass: bool, player_speed: int, can_bullet_pass: bool):
	_destroyable = destroyable
	_can_player_pass = can_player_pass
	_player_speed = player_speed
	_can_bullet_pass = can_bullet_pass
