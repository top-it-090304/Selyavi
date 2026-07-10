extends Enemy
class_name DefenderEnemy

@export var guard_radius: float = 650.0
@export var return_threshold: float = 850.0

var _is_returning: bool = false

func _ready():
	_type_enemy = TypeEnemy.DEFENDER
	super._ready()
	# Защитники более "ленивые" в патрулировании, стоят ближе к базе
	_notice_range = 900.0

func _physics_process(delta):
	if not is_instance_valid(creator_base):
		super._physics_process(delta)
		return

	var dist_to_base = global_position.distance_to(creator_base.global_position)

	# Если зашли слишком далеко от базы - принудительно возвращаемся
	if dist_to_base > return_threshold:
		_is_returning = true
	elif dist_to_base < guard_radius * 0.5:
		_is_returning = false

	super._physics_process(delta)

func _update_target():
	if _nav2d == null: return

	if _is_returning and is_instance_valid(creator_base):
		_nav2d.target_position = creator_base.global_position
		return

	# Стандартная логика выбора цели, но с приоритетом защиты базы
	var player = get_tree().get_first_node_in_group("players")
	if is_instance_valid(player):
		var dist_player_base = player.global_position.distance_to(creator_base.global_position)
		# Атакуем игрока только если он в радиусе охраны базы
		if dist_player_base <= guard_radius:
			_nav2d.target_position = player.global_position
			return

	# Если никто не угрожает базе, стоим рядом с ней
	if is_instance_valid(creator_base):
		_nav2d.target_position = creator_base.global_position
