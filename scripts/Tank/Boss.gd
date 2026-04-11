extends Enemy

var _spawn_timer: Timer
var _enemy_scene: PackedScene
var _hp_bar: ProgressBar
var _spawn_attempts: int = 0
var _max_spawn_attempts: int = 28
var _boss_minions: Array = []
const MAX_BOSS_MINIONS: int = 3

func _prune_minion_list():
	_boss_minions = _boss_minions.filter(func(n):
		return is_instance_valid(n) and not n.is_queued_for_deletion()
	)

func _ready():
	_type_enemy = TypeEnemy.BOSS
	super._ready()
	
	_setup_hp_bar()
	
	_enemy_scene = load("res://scenes/Tank/Enemy.tscn")
	
	_spawn_timer = Timer.new()
	_spawn_timer.wait_time = 7.0
	_spawn_timer.autostart = true
	_spawn_timer.timeout.connect(_spawn_minion)
	add_child(_spawn_timer)

func _setup_hp_bar():
	var canvas = CanvasLayer.new()
	add_child(canvas)
	
	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = _max_hp
	_hp_bar.value = _hp
	_hp_bar.show_percentage = false
	
	_hp_bar.custom_minimum_size = Vector2(400, 20)
	_hp_bar.anchor_left = 0.5
	_hp_bar.anchor_right = 0.5
	_hp_bar.anchor_top = 1
	_hp_bar.anchor_bottom = 0.1
	
	_hp_bar.offset_left = -200
	_hp_bar.offset_right = 200
	_hp_bar.offset_top = 20
	_hp_bar.offset_bottom = 45
	
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.6)
	style_bg.set_border_width_all(2)
	style_bg.border_color = Color(0.4, 0.4, 0.4, 1)
	_hp_bar.add_theme_stylebox_override("background", style_bg)
	
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(0.8, 0.0, 0.0, 0.9)
	_hp_bar.add_theme_stylebox_override("fill", style_fill)
	
	canvas.add_child(_hp_bar)

func take_damage(damage: int):
	super.take_damage(damage)
	if _hp_bar:
		_hp_bar.value = _hp

const MINION_SEPARATION: float = 72.0

func _is_valid_spawn_position(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(global_position, pos)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	if not result.is_empty():
		return false
	if not _is_clear_of_other_units(pos):
		return false
	return true

func _is_clear_of_other_units(pos: Vector2) -> bool:
	for node in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(node) or node == self:
			continue
		if node.is_queued_for_deletion():
			continue
		if node.global_position.distance_squared_to(pos) < MINION_SEPARATION * MINION_SEPARATION:
			return false

	var space_state = get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = 40.0
	var shape_query = PhysicsShapeQueryParameters2D.new()
	shape_query.set_shape(shape)
	shape_query.transform = Transform2D(0, pos)
	shape_query.exclude = [self]
	var hits = space_state.intersect_shape(shape_query)
	for hit in hits:
		var c = hit.collider
		if c is TileMap or c is StaticBody2D or c is CharacterBody2D:
			return false
	return true

func _get_valid_spawn_position() -> Vector2:
	var distance = randf_range(250, 400)
	var angle = randf_range(0, TAU)
	var offset = Vector2(cos(angle), sin(angle)) * distance
	var candidate = global_position + offset
	
	_spawn_attempts = 0
	while not _is_valid_spawn_position(candidate) and _spawn_attempts < _max_spawn_attempts:
		angle = randf_range(0, TAU)
		distance = randf_range(220, 420)
		offset = Vector2(cos(angle), sin(angle)) * distance
		candidate = global_position + offset
		_spawn_attempts += 1
	
	return candidate

func _spawn_minion():
	if not is_instance_valid(_player):
		return

	_prune_minion_list()
	if _boss_minions.size() >= MAX_BOSS_MINIONS:
		return

	var minion = _enemy_scene.instantiate()
	
	var allowed_types = [TypeEnemy.LIGHT, TypeEnemy.MEDIUM, TypeEnemy.HEAVY]
	minion._type_enemy = allowed_types[randi() % allowed_types.size()]
	
	var spawn_pos = _get_valid_spawn_position()
	minion.global_position = spawn_pos
	
	get_parent().add_child(minion)
	_boss_minions.append(minion)

	if minion.has_method("_find_targets"):
		minion._find_targets()
