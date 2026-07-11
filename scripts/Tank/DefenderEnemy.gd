extends Enemy
class_name DefenderEnemy

@export var guard_radius: float = 650.0
@export var return_threshold: float = 850.0
@export var patrol_dist: float = 400.0 # Дистанция, на которой он будет кружить вокруг базы

var _is_returning: bool = false
var _revenge_mode: bool = false
var _patrol_angle: float = 0.0
var _orbit_direction: float = 1.0 # 1.0 - по часовой, -1.0 - против часовой
var _collision_cooldown: float = 0.0 # Чтобы не дергался на углах

func _ready():
	_type_enemy = TypeEnemy.DEFENDER
	super._ready()
	_notice_range = 900.0
	_patrol_angle = randf() * TAU
	_orbit_direction = 1.0 if randf() > 0.5 else -1.0

func _physics_process(delta):
	if _collision_cooldown > 0:
		_collision_cooldown -= delta

	if not is_instance_valid(creator_base):
		if not _revenge_mode:
			_revenge_mode = true
			_current_state = State.CHASE
			_chase_speed += 20

		_patrol_angle += delta * 0.4 * _orbit_direction
		super._physics_process(delta)
		_check_physical_collision() # Проверка удара о стену
		return

	var dist_to_base = global_position.distance_to(creator_base.global_position)

	if dist_to_base > return_threshold:
		_is_returning = true
	elif dist_to_base < patrol_dist * 1.2:
		_is_returning = false

	# Вращаем угол в текущем направлении
	_patrol_angle += delta * 0.2 * _orbit_direction

	super._physics_process(delta)
	_check_physical_collision() # Проверка удара о стену

# ПРОВЕРКА ФИЗИЧЕСКОГО УДАРА О СТЕНУ
func _check_physical_collision():
	if _collision_cooldown > 0: return
	
	# Если мы во что-то врезались (move_and_slide сработал)
	if get_slide_collision_count() > 0:
		for i in range(get_slide_collision_count()):
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			
			# Если это стена, тайлсет или статический барьер
			if collider is TileMap or collider is StaticBody2D or (collider is Node and collider.is_in_group("walls")):
				_reverse_orbit()
				break

func _reverse_orbit():
	_orbit_direction *= -1.0
	# Смещаем угол посильнее (на ~25-30 градусов), чтобы танк сразу отвернул от стены
	_patrol_angle += 0.5 * _orbit_direction 
	_collision_cooldown = 0.6 # Даем время отъехать, прежде чем снова проверять коллизии

func _update_target():
	if _nav2d == null: return

	var map = get_world_2d().get_navigation_map()

	# 1. ЛОГИКА МЕСТИ (Режим охотника)
	if not is_instance_valid(creator_base):
		# Приоритет 1 — танк игрока (_player)
		if is_instance_valid(_player):
			_nav2d.target_position = _player.global_position
		# Приоритет 2 — база игрока (_base)
		elif is_instance_valid(_base):
			_nav2d.target_position = _base.global_position
		return

	# 2. ОХРАНА (Если игрок в радиусе защиты своей базы)
	if is_instance_valid(_player):
		var dist_player_base = _player.global_position.distance_to(creator_base.global_position)
		if dist_player_base <= guard_radius:
			_nav2d.target_position = _player.global_position
			return

	# 3. ПАТРУЛИРОВАНИЕ И ВОЗВРАТ (К своей живой базе)
	if is_instance_valid(creator_base):
		_set_ping_pong_orbit_target(creator_base.global_position, patrol_dist, map)

func _set_ping_pong_orbit_target(center: Vector2, radius: float, map: RID):
	var test_pos = center + Vector2(cos(_patrol_angle), sin(_patrol_angle)) * radius
	var closest_point = NavigationServer2D.map_get_closest_point(map, test_pos)

	# Если навигация говорит, что точка "в стене" (далеко от меша)
	if test_pos.distance_to(closest_point) > 70.0:
		if _collision_cooldown <= 0:
			_reverse_orbit()
		_nav2d.target_position = closest_point # Едем в ближайшую доступную
	else:
		_nav2d.target_position = test_pos

func _get_current_target():
	if _revenge_mode:
		# В режиме мести приоритет игроку без лишних проверок дистанции для прицеливания
		if is_instance_valid(_player):
			return _player
		if is_instance_valid(_base):
			return _base

	return super._get_current_target()
