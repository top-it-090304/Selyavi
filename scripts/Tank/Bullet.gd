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
var _ignored_body_rid: RID
var _has_dealt_damage: bool = false # Защита от двойного попадания

const PLASMA: int = 0
const MEDIUM: int = 1
const LIGHT: int = 2

func _ready():
	_bullet_sprite = $BulletSprite
	_bullet_sound = $PlasmaGunSound
	_velocity = Vector2(0, -1).rotated(rotation)
	_visibility_bullet = $VisibleOnScreenNotifier2D
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_visibility_bullet.screen_exited.connect(_on_screen_exited)

func _process(delta):
	var move_step = _velocity * _bullet_speed
	position += move_step
	_traveled_distance += move_step.length()
	if _traveled_distance >= _max_range: _destroy()

func _on_body_entered(body):
	if _has_dealt_damage: return
	if _ignored_body_rid.is_valid() and body.get_rid() == _ignored_body_rid: return

	# Проверка на физическое тело базы
	var parent = body.get_parent()
	if parent is Base:
		_handle_base_hit(parent)
		return

	if body is Player and not _is_player:
		_has_dealt_damage = true
		body.take_damage(_damage)
		_destroy()
	elif body is Enemy and _is_player:
		_has_dealt_damage = true
		body.take_damage(_damage)
		_destroy()
	elif body.has_method("can_bullet_pass"):
		if body.can_bullet_pass(): return
		_has_dealt_damage = true
		if body.has_method("destroyable") and body.destroyable(): body.destroy()
		_destroy()
	elif body is StaticBody2D:
		_has_dealt_damage = true
		_destroy()

func _on_area_entered(area):
	if _has_dealt_damage: return
	if area is Base:
		_handle_base_hit(area)

func _handle_base_hit(base_node: Base):
	if (_is_player and base_node.type_base == base_node.TypeBase.ENEMY) or (not _is_player and base_node.type_base == base_node.TypeBase.PLAYER):
		_has_dealt_damage = true
		base_node.take_damage(_damage)
		_destroy()

func _destroy():
	queue_free()

func init(type_bullet: int, is_player: bool, damage: int = 0, ignored_rid: RID = RID(), custom_range: float = -1.0):
	_type_bullet = type_bullet
	_is_player = is_player
	_damage = damage
	_ignored_body_rid = ignored_rid
	_update_visuals_and_speed()
	if custom_range > 0: _max_range = custom_range

func _update_visuals_and_speed():
	match _type_bullet:
		PLASMA:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Plasma.png")
			_bullet_speed = 7; _max_range = 600.0
		MEDIUM:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Medium_Shell.png")
			_bullet_speed = 4; _max_range = 275.0
		LIGHT:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Light_Shell.png")
			_bullet_speed = 6; _max_range = 900.0

func _on_screen_exited():
	var tween = create_tween()
	tween.tween_property(_bullet_sound, "volume_db", -80, 1.0)
	tween.finished.connect(queue_free)
