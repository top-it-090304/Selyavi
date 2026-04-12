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

# Визуальные элементы улучшений
var _antenna_sprite: Sprite2D
var _turret_sprite: Sprite2D
var _artifact_sprite: Sprite2D
var _shot_flash: AnimatedSprite2D

# Бонусы
@export var _damage_bonus: float = 1.3
@export var _armor_bonus: float = 0.2
@export var _rof_bonus: float = 0.8

# Новые показатели (улучшения штаба)
var _has_radar: bool = false
var _has_turret: bool = false
var _has_osmosis: bool = false
var _osmosis_timer: float = 0.0
var _turret_cooldown: float = 0.0
var _turret_range: float = 600.0
var _turret_damage: int = 25
var _turret_rof: float = 1.8

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
	_setup_feature_sprites()

	_spawn_timer = Timer.new(); _spawn_timer.wait_time = 0.1; _spawn_timer.one_shot = true; add_child(_spawn_timer); _spawn_timer.start()
	_heal_timer = Timer.new(); _heal_timer.wait_time = _heal_interval; _heal_timer.one_shot = false; add_child(_heal_timer)
	_heal_timer.timeout.connect(_on_heal_timeout); _heal_timer.start()

	_setup_base_collision()
	_update_spawn_interval()

	if _has_radar and type_base == TypeBase.PLAYER:
		var hud = get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("activate_radar"):
			hud.activate_radar()

	queue_redraw()

func _setup_feature_sprites():
	if type_base != TypeBase.PLAYER: return

	if _has_radar:
		_antenna_sprite = Sprite2D.new()
		_antenna_sprite.texture = load("res://assets/Antenna.png")
		_antenna_sprite.position = Vector2(10, -40)
		_antenna_sprite.scale = Vector2(0.05, 0.05)
		_antenna_sprite.z_index = 1
		add_child(_antenna_sprite)

	if _has_turret:
		_turret_sprite = Sprite2D.new()
		_turret_sprite.texture = load("res://assets/TurretGiantSniper_Top.png")
		_turret_sprite.position = Vector2.ZERO
		_turret_sprite.scale = Vector2(0.55, 0.55)
		_turret_sprite.z_index = 2
		add_child(_turret_sprite)

		# Создаем стандартную анимацию вспышки как у танков
		_shot_flash = AnimatedSprite2D.new()
		_shot_flash.sprite_frames = SpriteFrames.new()
		_shot_flash.sprite_frames.add_animation("Fire")
		_shot_flash.sprite_frames.set_animation_speed("Fire", 25.0)
		_shot_flash.sprite_frames.set_animation_loop("Fire", false)

		var textures = [
			null,
			"res://assets/future_tanks/PNG/Effects/Explosion_B.png",
			"res://assets/future_tanks/PNG/Effects/Explosion_C.png",
			"res://assets/future_tanks/PNG/Effects/Explosion_D.png",
			"res://assets/future_tanks/PNG/Effects/Explosion_E.png",
			"res://assets/future_tanks/PNG/Effects/Explosion_F.png",
			"res://assets/future_tanks/PNG/Effects/Explosion_G.png",
			"res://assets/future_tanks/PNG/Effects/Explosion_H.png",
			null
		]
		for tex_path in textures:
			if tex_path: _shot_flash.sprite_frames.add_frame("Fire", load(tex_path))
			else: _shot_flash.sprite_frames.add_frame("Fire", null)

		_shot_flash.scale = Vector2(0.4, 0.4)
		_shot_flash.z_index = 3
		_turret_sprite.add_child(_shot_flash)
		_shot_flash.position = Vector2(240, 0)
		_shot_flash.rotation = -PI/2

	if _has_osmosis:
		_artifact_sprite = Sprite2D.new()
		_artifact_sprite.texture = load("res://assets/backround/PNG/Props/Artifact.png")
		_artifact_sprite.scale = Vector2(1.0, 1.0)
		_artifact_sprite.z_index = 1
		add_child(_artifact_sprite)

func _apply_upgrades():
	if type_base == TypeBase.ENEMY:
		_max_hp = 250
		return

	if SaveManager:
		var hp_lv = SaveManager.get_player_stat("base_hp_level", 0)
		var hps = [150, 200, 250, 350]
		_max_hp = hps[clampi(hp_lv, 0, hps.size()-1)]

		var heal_lv = SaveManager.get_player_stat("base_heal_level", 0)
		var heals = [5, 7, 10]
		_heal_amount = heals[clampi(heal_lv, 0, heals.size()-1)]

		var bonus_lv = SaveManager.get_player_stat("base_bonus_level", 0)
		var bonuses = [1.1, 1.2, 1.5]
		_damage_bonus = bonuses[clampi(bonus_lv, 0, bonuses.size()-1)]

		var feature_type = SaveManager.get_player_stat("base_feature_type", 0)
		_has_radar = (feature_type == 1)
		_has_turret = (feature_type == 2)
		_has_osmosis = (feature_type == 3)

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
	_smoke_particles.z_index = 10
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
	_fire_particles.z_index = 11
	var gradient = Gradient.new()
	gradient.set_color(0, Color(1, 0.9, 0.2, 1)); gradient.add_point(0.2, Color(1, 0.4, 0, 1)); gradient.add_point(0.5, Color(0.8, 0.1, 0, 0.8)); gradient.add_point(1.0, Color(0.2, 0.2, 0.2, 0))
	_fire_particles.color_ramp = gradient
	add_child(_fire_particles)

func _draw():
	if type_base == TypeBase.PLAYER:
		draw_circle(Vector2.ZERO, _heal_radius, Color(0.0, 1.0, 0.0, 0.1))
		draw_arc(Vector2.ZERO, _heal_radius, 0, TAU, 64, Color(0.0, 1.0, 0.0, 0.3), 3.0, true)

		if _has_turret:
			draw_arc(Vector2.ZERO, _turret_range, 0, TAU, 64, Color(1.0, 0.3, 0.3, 0.1), 2.0)

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

func take_heal(amount: int):
	var old_hp = _hp
	_hp = clampi(_hp + amount, 0, _max_hp)
	if old_hp < _max_hp:
		_update_destruction_effects()

func _update_destruction_effects():
	var hp_percent = float(_hp) / float(_max_hp)

	if hp_percent > 0.7:
		_damage_tier = 0
		_smoke_particles.emitting = false
		_fire_particles.emitting = false
	elif hp_percent <= 0.15:
		if _damage_tier != 3:
			_damage_tier = 3; _smoke_particles.emitting = true; _smoke_particles.amount = 60; _smoke_particles.color = Color(0.05, 0.05, 0.05, 0.9); _fire_particles.emitting = true
	elif hp_percent <= 0.4:
		if _damage_tier != 2:
			_damage_tier = 2; _smoke_particles.emitting = true; _smoke_particles.amount = 45; _smoke_particles.color = Color(0.1, 0.1, 0.1, 0.8); _fire_particles.emitting = false
	elif hp_percent <= 0.7:
		if _damage_tier != 1:
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
	var exclude_list: Array[RID] = []
	exclude_list.append(get_rid())
	if is_instance_valid(_base_body): exclude_list.append(_base_body.get_rid())
	query.exclude = exclude_list
	var results = space_state.intersect_shape(query)
	for result in results:
		if result.collider is TileMap or result.collider is StaticBody2D or result.collider is CharacterBody2D: return false
	return true

func _process(delta):
	if type_base == TypeBase.ENEMY:
		_time_since_last_check += delta
		if _time_since_last_check >= _spawn_interval:
			_spawn_enemy(); _time_since_last_check = 0
	else:
		if _has_osmosis:
			_osmosis_timer += delta
			if _osmosis_timer >= 5.0:
				if _hp < _max_hp: # Условие: лечим и показываем эффекты только если база задамажена
					take_heal(10)
					_spawn_heal_plus_effects()
				_osmosis_timer = 0.0
		if _has_turret:
			_turret_cooldown -= delta
			_update_turret_rotation(delta)
			if _turret_cooldown <= 0:
				_fire_turret()

func _spawn_heal_plus_effects():
	for i in range(3):
		var plus = Sprite2D.new()
		plus.texture = load("res://assets/plus.png")
		# Еще сильнее уменьшил плюсы (масштаб 0.04)
		plus.scale = Vector2(0.04, 0.04)
		plus.modulate = Color(0.2, 1.0, 0.2, 0.8)
		# Плюсы будут поверх спрайта осмоса (z_index 5)
		plus.z_index = 5
		var offset = Vector2(randf_range(-60, 60), randf_range(-60, 60))
		plus.global_position = global_position + offset
		get_parent().add_child(plus)

		var tween = create_tween()
		var target_pos = plus.global_position + Vector2(randf_range(-30, 30), -100)
		tween.tween_property(plus, "global_position", target_pos, 1.5).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(plus, "modulate:a", 0.0, 1.5)
		tween.parallel().tween_property(plus, "scale", Vector2(0.06, 0.06), 1.5)
		tween.finished.connect(func(): plus.queue_free())

func _update_turret_rotation(delta):
	if !_has_turret or !_turret_sprite: return
	var target = _find_nearest_enemy()
	if target:
		var dir = (target.global_position - global_position).normalized()
		_turret_sprite.rotation = lerp_angle(_turret_sprite.rotation, dir.angle(), delta * 5.0)

func _find_nearest_enemy() -> Node2D:
	var enemies = get_tree().get_nodes_in_group("enemies")
	var target = null
	var min_dist = _turret_range
	var space_state = get_world_2d().direct_space_state

	for e in enemies:
		if is_instance_valid(e):
			var dist = global_position.distance_to(e.global_position)
			if dist < min_dist:
				var query = PhysicsRayQueryParameters2D.create(global_position, e.global_position)
				query.exclude = [get_rid()]
				if is_instance_valid(_base_body): query.exclude.append(_base_body.get_rid())
				var result = space_state.intersect_ray(query)
				if result.is_empty() or result.collider == e:
					min_dist = dist
					target = e
	return target

func _fire_turret():
	var target = _find_nearest_enemy()
	if target:
		var dir = (target.global_position - global_position).normalized()

		if _shot_flash:
			_shot_flash.play("Fire")

		var shoot_tween = create_tween()
		shoot_tween.tween_property(_turret_sprite, "position", -dir * 20.0, 0.05)
		shoot_tween.parallel().tween_property(_turret_sprite, "scale", Vector2(0.5, 0.5), 0.05)
		shoot_tween.tween_property(_turret_sprite, "position", Vector2.ZERO, 0.15)
		shoot_tween.parallel().tween_property(_turret_sprite, "scale", Vector2(0.55, 0.55), 0.15)

		var bullet_scene = load("res://scenes/Tank/Bullet.tscn")
		var bullet = bullet_scene.instantiate()

		bullet.global_position = global_position + dir * 185.0
		bullet.rotation = dir.angle() + PI/2

		get_parent().add_child(bullet)

		if bullet.has_method("init"):
			var ignored_rid = _base_body.get_rid() if is_instance_valid(_base_body) else get_rid()
			bullet.init(1, true, _turret_damage, ignored_rid)
			var sprite = bullet.get_node_or_null("BulletSprite")
			if sprite: sprite.texture = load("res://assets/future_tanks/PNG/Effects/Heavy_Shell.png")

		_play_shoot_sound()
		_turret_cooldown = _turret_rof

func _play_shoot_sound():
	var player = AudioStreamPlayer2D.new()
	player.stream = load("res://assets/sounds/vystrel-tanka.mp3")
	player.volume_db = -5.0
	player.pitch_scale = randf_range(0.8, 1.1)
	player.bus = "SFX"
	add_child(player)
	player.play()
	player.finished.connect(func(): player.queue_free())
