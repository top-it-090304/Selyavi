extends Node2D

var _radius: float = 130.0
var _damage: int = 45
var _timer: float = 0.0
var _duration: float = 2.5 # Время до удара
var _shell_texture: Texture2D

func _ready():
	_shell_texture = load("res://assets/future_tanks/PNG/Effects/Heavy_Shell.png")
	queue_redraw()
	_play_incoming_sound()

func _process(delta):
	_timer += delta
	queue_redraw()
	if _timer >= _duration:
		_explode()
		queue_free()

func _draw():
	# Рисуем внешний контур
	draw_arc(Vector2.ZERO, _radius, 0, TAU, 64, Color(1, 0, 0, 0.6), 3.0)

	# Рисуем заполняющийся круг из центра
	var fill_ratio = _timer / _duration
	draw_circle(Vector2.ZERO, _radius * fill_ratio, Color(1, 0, 0, 0.35))

	# Визуализация "падающего" снаряда
	if _shell_texture:
		var fill_inv = 1.0 - fill_ratio
		var shell_pos = Vector2(0, -600 * fill_inv)
		var shell_scale = 0.4 + 0.6 * fill_inv

		draw_set_transform(shell_pos, PI, Vector2(shell_scale, shell_scale))
		draw_texture(_shell_texture, -_shell_texture.get_size() / 2.0)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

func _explode():
	_spawn_explosion_effects()

	var space_state = get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = _radius

	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = global_transform
	query.collide_with_areas = true # ВАЖНО: База — это Area2D
	query.collide_with_bodies = true

	var results = space_state.intersect_shape(query)

	# Используем словарь, чтобы не дамажить один и тот же объект дважды (если попали и в Area, и в Body)
	var targets_to_damage = {}

	for result in results:
		var collider = result.collider
		if not is_instance_valid(collider): continue

		var final_target = collider

		# Если попали в дочернее тело базы или игрока — берем родителя
		if not final_target.has_method("take_damage"):
			if final_target.get_parent() and final_target.get_parent().has_method("take_damage"):
				final_target = final_target.get_parent()

		if final_target.has_method("take_damage"):
			targets_to_damage[final_target.get_instance_id()] = final_target

	# Наносим урон всем найденным целям
	for target_id in targets_to_damage:
		var target = targets_to_damage[target_id]
		# Дамажим только Игрока, его Базу и Стены
		if target.is_in_group("players") or target.is_in_group("bases") or target.has_method("destroyable"):
			target.take_damage(_damage)

func _spawn_explosion_effects():
	if AudioManager:
		AudioManager.play_bullet_sound(1, global_position)

func _play_incoming_sound():
	pass
