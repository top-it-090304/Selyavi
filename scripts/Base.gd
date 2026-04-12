class_name Base
extends Area2D

enum TypeBase { PLAYER, ENEMY }

signal base_state(type: int)

@export var type_base: int = TypeBase.ENEMY
@export var _hp: int = 100
@export var _max_hp: int = 100

var _spawn_timer: Timer
var _heal_timer: Timer
var _enemy_position: Marker2D
var _enemy_scene: PackedScene
var _base_body: StaticBody2D

@export var _max_enemies: int = 3
@export var _heal_amount: int = 7
@export var _heal_interval: float = 1.0
@export var _heal_radius: float = 300.0
@export var _spawn_interval: float = 6.0
var _time_since_last_check: float = 0.0

# Эффекты частиц
var _smoke_particles: CPUParticles2D
var _fire_particles: CPUParticles2D
var _damage_tier: int = 0

# Бонусы
@export var _damage_bonus: float = 1.3
@export var _armor_bonus: float = 0.2
@export var _rof_bonus: float = 0.8

var _my_spawned_enemies: Array = []

func _enter_tree():
	add_to_group("bases")

func _ready():
	_sync_current_level()
	_apply_upgrades()
	_hp = _max_hp

	area_entered.connect(_on_bullet_entered)
	_enemy_scene = load("res://scenes/Tank/Enemy.tscn")
	_enemy_position = get_node_or_null("EnemyPosition")

	_setup_base_appearance()
	_setup_particles()

	_spawn_timer = Timer.new(); _spawn_timer.wait_time = 0.1; _spawn_timer.one_shot = true; add_child(_spawn_timer); _spawn_timer.start()
	_heal_timer = Timer.new(); _heal_timer.wait_time = _heal_interval; _heal_timer.one_shot = false; add_child(_heal_timer)
	_heal_timer.timeout.connect(_on_heal_timeout); _heal_timer.start()

	_setup_base_collision()
	_update_spawn_interval()
	queue_redraw()

func _apply_upgrades():
	if type_base == TypeBase.ENEMY:
		_max_hp = 250
		return

	# Для игрока подгружаем из SaveManager
	if SaveManager:
		# 1. HP (Защита)
		var hp_lv = SaveManager.get_player_stat("base_hp_level", 0)
		var hps = [150, 200, 250, 350]
		_max_hp = hps[clampi(hp_lv, 0, hps.size()-1)]

		# 2. Heal (Ремонт)
		var heal_lv = SaveManager.get_player_stat("base_heal_level", 0)
		var heals = [5, 7, 10]
		_heal_amount = heals[clampi(heal_lv, 0, heals.size()-1)]

		# 3. Bonus (Тактика - урон)
		var bonus_lv = SaveManager.get_player_stat("base_bonus_level", 0)
		var bonuses = [1.1, 1.2, 1.5]
		_damage_bonus = bonuses[clampi(bonus_lv, 0, bonuses.size()-1)]

func _setup_particles():
	_smoke_particles = CPUParticles2D.new()
	_smoke_particles.texture = load("res://assets/future_tanks/PNG/Effects/Smoke_A.png")
	_smoke_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_smoke_particles.emission_sphere_radius = 35.0
	_smoke_particles.spread = 180.0
	_smoke_particles.gravity = Vector2(0, -120)
	_smoke_particles.scale_amount_min = 0.2
	_smoke_particles.scale_amount_max = 0.6
	_smoke_particles.emitting = false
	_smoke_particles.amount = 40
	_smoke_particles.lifetime = 1.5
	_smoke_particles.preprocess = 1.0
	add_child(_smoke_particles)

	_fire_particles = CPUParticles2D.new()
	_fire_particles.texture = load("res://assets/future_tanks/PNG/Effects/Smoke_A.png")
	_fire_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_fire_particles.emission_sphere_radius = 25.0
	_fire_particles.gravity = Vector2(0, -200)
	_fire_particles.initial_velocity_min = 60.0
	_fire_particles.initial_velocity_max = 120.0
	_fire_particles.scale_amount_min = 0.1
	_fire_particles.scale_amount_max = 0.3
	_fire_particles.emitting = false
	_fire_particles.amount = 80
	_fire_particles.lifetime = 0.5
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 0.9, 0.2, 1)); gradient.add_point(0.2, Color(1, 0.4, 0, 1)); gradient.add_point(0.5, Color(0.8, 0.1, 0, 0.8)); gradient.add_point(1.0, Color(0.2, 0.2, 0.2, 0))
	_fire_particles.color_ramp = gradient
	add_child(_fire_particles)

func _draw():
	if type_base == TypeBase.PLAYER:
		draw_circle(Vector2.ZERO, _heal_radius, Color(0.0, 1.0, 0.0, 0.1))
		draw_arc(Vector2.ZERO, _heal_radius, 0, TAU, 64, Color(0.0, 1.0, 0.0, 0.3), 3.0, true)

func _sync_current_level():
	if SaveManager == null: return
	var scene_name = get_tree().current_scene.name
	if scene_name.contains("Level_"):
		var lvl = scene_name.get_slice("_", 1).to_int()
		if lvl > 0: SaveManager.current_level = lvl

func _update_spawn_interval():
	var lvl = 1
	if SaveManager: lvl = SaveManager.current_level
	_spawn_interval = 10.0 if lvl <= 5 else (8.0 if lvl <= 10 else 6.0)

func _setup_base_collision():
	_base_body = StaticBody2D.new(); _base_body.name = "BaseStaticBody"; add_child(_base_body)
	var cs = CollisionShape2D.new(); var circle = CircleShape2D.new()
	var area_shape = get_node_or_null("CollisionShape2D")
	circle.radius = area_shape.shape.radius if area_shape and area_shape.shape is CircleShape2D else 60.0
	cs.shape = circle; _base_body.add_child(cs)

func _on_bullet_entered(area):
	if area.has_method("is_player"):
		var is_player_bullet = area.is_player()
		if (is_player_bullet and type_base == TypeBase.ENEMY) or (not is_player_bullet and type_base == TypeBase.PLAYER):
			take_damage(area.get("_damage") if "_damage" in area else 25)
			if area.has_method("_destroy"): area._destroy()
			else: area.queue_free()

func _on_heal_timeout():
	if type_base != TypeBase.PLAYER: return
	var player = get_tree().get_first_node_in_group("players")
	if player == null or not is_instance_valid(player): return
	if global_position.distance_to(player.global_position) <= _heal_radius:
		if player.has_method("take_heal"): player.take_heal(_heal_amount)

func _setup_base_appearance():
	var sprite = get_node_or_null("Sprite2D")
	if sprite != null: sprite.modulate = Color(1.0, 0.4, 0.4) if type_base == TypeBase.ENEMY else Color(0.5, 1.0, 0.8)

func take_damage(amount: int):
	_hp -= amount
	_update_damage_visuals()
	_update_destruction_effects()
	if type_base == TypeBase.PLAYER:
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("trigger_base_attack_warning"): hud.trigger_base_attack_warning(global_position)
	if _hp <= 0: _destroy()

func _update_destruction_effects():
	var hp_percent = float(_hp) / float(_max_hp)
	if hp_percent <= 0.15:
		if _damage_tier < 3:
			_damage_tier = 3; _smoke_particles.emitting = true; _smoke_particles.amount = 60; _smoke_particles.color = Color(0.05, 0.05, 0.05, 0.9); _fire_particles.emitting = true
	elif hp_percent <= 0.4:
		if _damage_tier < 2:
			_damage_tier = 2; _smoke_particles.emitting = true; _smoke_particles.amount = 45; _smoke_particles.color = Color(0.1, 0.1, 0.1, 0.8); _fire_particles.emitting = false
	elif hp_percent <= 0.7:
		if _damage_tier < 1:
			_damage_tier = 1; _smoke_particles.emitting = true; _smoke_particles.amount = 20; _smoke_particles.color = Color(0.5, 0.5, 0.5, 0.6); _fire_particles.emitting = false

func _update_damage_visuals():
	var sprite = get_node_or_null("Sprite2D") if get_node_or_null("Sprite2D") else self
	var target_color = Color(1.0, 0.4, 0.4) if type_base == TypeBase.ENEMY else Color(0.5, 1.0, 0.8)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(5, 5, 5), 0.05)
	tween.tween_property(sprite, "modulate", target_color, 0.05)

func _destroy():
	base_state.emit(type_base)
	queue_free()

func _spawn_enemy():
	if type_base == TypeBase.PLAYER: return

	# БЛОКИРОВКА СПАВНА ВО ВРЕМЯ ОБУЧЕНИЯ
	if get_tree().has_group("tutorial"): return

	_my_spawned_enemies = _my_spawned_enemies.filter(func(enemy): return is_instance_valid(enemy) and not enemy.is_queued_for_deletion())
	if _my_spawned_enemies.size() >= _max_enemies: return
	var spawn_pos = _get_safe_spawn_pos()
	if spawn_pos != Vector2.ZERO:
		var enemy = _enemy_scene.instantiate()
		if enemy.get("type_enemy") == 5: enemy.set("type_enemy", randi() % 3)
		enemy.global_position = spawn_pos
		get_parent().add_child(enemy)
		_my_spawned_enemies.append(enemy)

func _get_safe_spawn_pos() -> Vector2:
	var player = get_tree().get_first_node_in_group("players")
	var player_base = null
	for b in get_tree().get_nodes_in_group("bases"):
		if b.type_base == TypeBase.PLAYER: player_base = b; break
	var target_pos = player_base.global_position if is_instance_valid(player_base) else (player.global_position if is_instance_valid(player) else Vector2.ZERO)
	var base_angle = (target_pos - global_position).angle() if target_pos != Vector2.ZERO else 0.0
	for attempts in range(30):
		var angle = base_angle + randf_range(-PI/4, PI/4) if target_pos != Vector2.ZERO else randf_range(0, 2*PI)
		var spawn_pos = global_position + Vector2(cos(angle), sin(angle)) * randf_range(250, 400)
		if _is_pos_safe(spawn_pos): return spawn_pos
	return Vector2.ZERO

func _is_pos_safe(pos: Vector2) -> bool:
	var space_state = get_world_2d().direct_space_state
	var shape = CircleShape2D.new(); shape.radius = 45.0
	var query = PhysicsShapeQueryParameters2D.new(); query.set_shape(shape); query.transform = Transform2D(0, pos)

	# ФИКС ОШИБКИ RID
	var exclude_list: Array[RID] = []
	exclude_list.append(get_rid())
	if is_instance_valid(_base_body): exclude_list.append(_base_body.get_rid())
	query.exclude = exclude_list

	var results = space_state.intersect_shape(query)
	for result in results:
		if result.collider is TileMap or result.collider is StaticBody2D or result.collider is CharacterBody2D: return false
	return true

func _process(delta):
	_time_since_last_check += delta
	if _time_since_last_check >= _spawn_interval:
		_spawn_enemy(); _time_since_last_check = 0
