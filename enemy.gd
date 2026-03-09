extends CharacterBody2D
class_name Enemy

enum State { PATROL, CHASE }

# region private fields
var _current_state: int
var _detection_area: Area2D
var _hp: int = 10
var _player: Player
var _base: Base
@export var _patrol_speed: int = 90
@export var _chase_speed: int = 100
var _velocity: Vector2 = Vector2.ZERO
var _bullet_position: Position2D
var _shoot_timer: Timer
var _gun: Sprite
var _nav2d: NavigationAgent2D
var _ray_cast: RayCast2D
# endregion

var bullet_scene: PackedScene

func _ready():
	_init()
	add_child(_shoot_timer)
	
	if _nav2d != null:
		_nav2d.max_speed = _patrol_speed
		_nav2d.target_desired_distance = 10.0
		_nav2d.path_desired_distance = 5.0

func _physics_process(delta):
	if not is_instance_valid(_base):
		destroy()
		return
	
	_update_target()
	_aim_gun()
	_update_ray_cast()
	_check_and_fire()
	_move_enemy()
	_velocity = move_and_slide(_velocity)

func _update_target():
	if _nav2d == null:
		return
	
	match _current_state:
		State.PATROL:
			if _base != null and is_instance_valid(_base):
				_nav2d.target_location = _base.global_position
			else:
				destroy()
		
		State.CHASE:
			if _player != null and is_instance_valid(_player):
				_nav2d.target_location = _player.global_position

func _aim_gun():
	if _gun == null:
		return
	
	var target = _get_current_target()
	if target == null or not is_instance_valid(target):
		return
	
	var direction_to_target = (target.global_position - _gun.global_position).normalized()
	var target_angle = direction_to_target.angle()
	
	var gun_angle = target_angle + PI / 2
	_gun.global_rotation = gun_angle

func _move_enemy():
	if _nav2d == null:
		return
	
	var should_move = false
	
	match _current_state:
		State.PATROL:
			should_move = true
		State.CHASE:
			should_move = not _is_target_visible()
	
	if should_move and not _nav2d.is_navigation_finished():
		var next_location = _nav2d.get_next_location()
		var direction = (next_location - global_position).normalized()
		
		var current_speed = _patrol_speed if _current_state == State.PATROL else _chase_speed
		_velocity = direction * current_speed
		
		if _velocity.length() > 0.1:
			rotation_degrees = _velocity.angle() * 180 / PI + 90
	else:
		_velocity = Vector2.ZERO

func _update_ray_cast():
	if _ray_cast == null:
		return
	
	var target = _get_current_target()
	if target == null or not is_instance_valid(target):
		return
	
	var direction_to_target = (target.global_position - _bullet_position.global_position).normalized()
	var distance_to_target = global_position.distance_to(target.global_position)
	
	_ray_cast.cast_to = direction_to_target * distance_to_target
	_ray_cast.enabled = true

func _is_target_visible() -> bool:
	if _ray_cast == null:
		return false
	
	if _ray_cast.is_colliding():
		var collider = _ray_cast.get_collider()
		
		if collider != null and is_instance_valid(collider):
			if collider == _player or collider == _base:
				return true
		return false
	
	var target = _get_current_target()
	return target != null and is_instance_valid(target)

func _get_current_target():
	if _current_state == State.CHASE:
		return _player if (_player != null and is_instance_valid(_player)) else null
	else:
		return _base if (_base != null and is_instance_valid(_base)) else null

func _check_and_fire():
	var target = _get_current_target()
	if target == null:
		return
	
	if _is_target_visible():
		_fire_at_target(target)

func _on_detection_area_entered(body: Node):
	if body == _player and is_instance_valid(_player):
		_current_state = State.CHASE

func _on_detection_area_exited(body: Node):
	if body == _player:
		if _base != null and is_instance_valid(_base):
			_current_state = State.PATROL

func take_damage(damage: int):
	_hp -= damage
	if _hp <= 0:
		destroy()

func destroy():
	queue_free()

func _fire_at_target(target: Node2D):
	if _shoot_timer.time_left > 0:
		return
	
	var bullet = bullet_scene.instantiate()
	
	var distance = global_position.distance_to(target.global_position)
	
	var base_accuracy = 0.9
	var distance_factor = clamp(distance / 500.0, 0.0, 0.5)
	var final_accuracy = base_accuracy - distance_factor
	
	var direction_to_target = (target.global_position - _gun.global_position).normalized()
	var base_angle = direction_to_target.angle()
	var gun_angle = base_angle + PI / 2
	
	if randf() > final_accuracy:
		var miss_intensity = 1.0 - final_accuracy
		var max_angle_offset = deg_to_rad(30.0) * miss_intensity
		var random_offset = randf_range(-max_angle_offset, max_angle_offset)
		
		var final_angle = gun_angle + random_offset
		bullet.global_rotation = final_angle
	else:
		bullet.global_rotation = gun_angle
	
	bullet.global_position = _bullet_position.global_position
	
	get_tree().root.add_child(bullet)
	bullet.init(0, false)  # TypeBullet.Plasma = 0
	_shoot_timer.start()

func _init():
	add_to_group("enemies")
	_nav2d = $NavigationAgent2D
	_ray_cast = $RayCast2D
	
	var navigation2d = get_node("/root/Field/Navigation2D") as Navigation2D
	if navigation2d != null:
		_nav2d.set_navigation(navigation2d)
	
	_current_state = State.PATROL
	_detection_area = $DetectionArea
	_player = get_node("/root/Field/PlayerTank") as Player
	_base = get_node("/root/Field/Base") as Base
	_gun = $BodyTank/Gun
	_bullet_position = $BodyTank/Gun/BulletPosition
	
	_detection_area.body_entered.connect(_on_detection_area_entered)
	_detection_area.body_exited.connect(_on_detection_area_exited)
	
	bullet_scene = load("res://scenes/Tank/Bullet.tscn")
	_shoot_timer = Timer.new()
	_shoot_timer.wait_time = 1.0
	_shoot_timer.one_shot = true
