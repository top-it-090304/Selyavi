extends Enemy
class_name TwinBoss

enum Role { AGGRESSOR, BASE_ATTACKER }

const HEAL_RATE: float = 7.0
const LINE_DAMAGE: int = 15
const LINE_DAMAGE_COOLDOWN: float = 1.0
const LINE_HIT_RADIUS: float = 40.0

var twin: TwinBoss = null
var role: int = Role.AGGRESSOR

var _heal_accum: float = 0.0
var _line_damage_cooldown: float = 0.0
var _thread_line: Line2D

func _ready():
	_type_enemy = TypeEnemy.BOSS
	super._ready()
	_setup_thread_line()
	_apply_role_tint()

func setup_twin(other: TwinBoss, initial_role: int):
	twin = other
	role = initial_role
	_apply_role_tint()

func _apply_role_tint():
	if _body == null: return
	_body.modulate = Color(1.0, 0.55, 0.55) if role == Role.AGGRESSOR else Color(0.55, 0.7, 1.0)

func _setup_thread_line():
	_thread_line = Line2D.new()
	_thread_line.width = 6.0
	_thread_line.default_color = Color(1.0, 0.85, 0.2, 0.85)
	_thread_line.z_index = 5
	_thread_line.visible = false
	add_child(_thread_line)

func take_heal(amount: float):
	_hp = min(_hp + int(amount), _max_hp)
	tank_health_changed.emit(_hp, _max_hp)

func _physics_process(delta):
	super._physics_process(delta)
	_update_thread(delta)

func _update_thread(delta):
	if not is_instance_valid(twin):
		if _thread_line: _thread_line.visible = false
		return

	_thread_line.visible = true
	_thread_line.clear_points()
	_thread_line.add_point(Vector2.ZERO)
	_thread_line.add_point(to_local(twin.global_position))

	_heal_accum += delta
	if _heal_accum >= 1.0:
		_heal_accum -= 1.0
		twin.take_heal(HEAL_RATE)

	# Считаем урон игроку только с одной стороны нити, чтобы не удвоить его
	if get_instance_id() < twin.get_instance_id():
		_check_thread_player_hit(delta)

func _check_thread_player_hit(delta):
	if _line_damage_cooldown > 0:
		_line_damage_cooldown -= delta
		return

	var player = get_tree().get_first_node_in_group("players")
	if not is_instance_valid(player): return

	var closest = Geometry2D.get_closest_point_to_segment(player.global_position, global_position, twin.global_position)
	if player.global_position.distance_to(closest) <= LINE_HIT_RADIUS:
		if player.has_method("take_damage"):
			player.take_damage(LINE_DAMAGE)
			_line_damage_cooldown = LINE_DAMAGE_COOLDOWN

func _get_current_target():
	if role == Role.BASE_ATTACKER and is_instance_valid(_base):
		return _base
	return super._get_current_target()

func _destroy():
	if is_instance_valid(twin):
		twin.twin = null
		twin.role = Role.AGGRESSOR
		twin._apply_role_tint()
	super._destroy()
