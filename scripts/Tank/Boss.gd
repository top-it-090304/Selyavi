extends Enemy

var _spawn_timer: Timer
var _enemy_scene: PackedScene

var _hp_bar: ProgressBar

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
	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = _max_hp
	_hp_bar.value = _hp
	_hp_bar.show_percentage = false
	_hp_bar.size = Vector2(120, 8)
	_hp_bar.position = Vector2(-60, 70) # Сзади танка (положительный Y)

	# Отрисовка под танком
	_hp_bar.show_behind_parent = true
	_hp_bar.z_index = -1

	# Стилизация HP-бара
	var style_bg = StyleBoxFlat.new()
	style_bg.bg_color = Color(0.1, 0.1, 0.1, 0.4)
	_hp_bar.add_theme_stylebox_override("background", style_bg)

	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = Color(0.8, 0.0, 0.0, 0.7)
	_hp_bar.add_theme_stylebox_override("fill", style_fill)

	add_child(_hp_bar)

func take_damage(damage: int):
	super.take_damage(damage)
	if _hp_bar:
		_hp_bar.value = _hp

func _spawn_minion():
	if not is_instance_valid(_player): return

	var minion = _enemy_scene.instantiate()

	# Ограничиваем типы миньонов (только Light, Medium, Heavy)
	var allowed_types = [TypeEnemy.LIGHT, TypeEnemy.MEDIUM, TypeEnemy.HEAVY]
	minion._type_enemy = allowed_types[randi() % allowed_types.size()]

	# Спавним чуть в стороне от босса
	var offset = Vector2(randf_range(-100, 100), randf_range(-100, 100))
	minion.global_position = global_position + offset

	get_parent().add_child(minion)

	# Миньон сразу знает про отсутствие базы и преследует игрока
	if minion.has_method("_find_targets"):
		minion._find_targets()
