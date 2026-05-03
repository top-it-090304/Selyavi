class_name Player
extends Tank

signal health_changed(current_health, max_health)
signal lives_changed(current_lives)
signal money_changed(current_money)
signal ammo_changed(slot_idx)

var _lives: int = 3
var _money: int = 0
var _speed: int = 250
var _start_position: Vector2
var is_scope_on: bool = true

var _joystick: Node
var _aim: Node
var _type_bullet: int = 0
var _ammo_loadout: Array[int] = [2, 0, 1]
var _current_ammo_slot: int = 0
var _type_body: int = 1
var _type_gun: int = 1
var _color: int = 0
var _invul_tween: Tween

var _controls_inverted: bool = false
var _inverse_timer: float = 0.0

const PLASMA: int = 0
const MEDIUM: int = 1
const LIGHT: int = 2
const HE: int = 3
const BOPS: int = 4
const RICOCHET: int = 5

var _ricochet_bullet_scene: PackedScene

const BODY_LIGHT = 0; const BODY_MEDIUM = 1; const BODY_HEAVY = 2; const BODY_LMEDIUM = 3; const BODY_MHEAVY = 4
const GUN_LIGHT = 0; const GUN_MEDIUM = 1; const GUN_HEAVY = 2; const GUN_LMEDIUM = 3; const GUN_MHEAVY = 4
const COLOR_BROWN = 0; const COLOR_GREEN = 1; const COLOR_AZURE = 2

func _ready():
	add_to_group("players")
	_init_base_tank()
	_ricochet_bullet_scene = load("res://scenes/Tank/RicochetBullet.tscn")
	_start_position = global_position
	_load_all_data()

	call_deferred("_connect_hud_controls")
	_start_invulnerability(3.0)

	if AudioManager != null:
		if not AudioManager.sfx_volume_changed.is_connected(_on_sfx_volume_changed):
			AudioManager.sfx_volume_changed.connect(_on_sfx_volume_changed)
	
	if GameManager != null:
		if not GameManager.on_visual_scope_updated.is_connected(_toggle_scope):
			GameManager.on_visual_scope_updated.connect(_toggle_scope)
		is_scope_on = GameManager.is_scope_currently_enabled()

	if SaveManager != null:
		if not SaveManager.settings_changed.is_connected(_apply_camera_fov):
			SaveManager.settings_changed.connect(_apply_camera_fov)
	call_deferred("_apply_camera_fov")

func set_controls_inverted(inverted: bool, duration: float = 0.0):
	_controls_inverted = inverted
	if inverted and duration > 0:
		_inverse_timer = duration
	elif !inverted and _inverse_timer <= 0:
		_controls_inverted = false

func _connect_hud_controls():
	var hud = get_tree().get_first_node_in_group("hud")
	if hud:
		_joystick = hud.find_child("Joystick", true)
		_aim = hud.find_child("Aim", true)
		if _joystick: _joystick.use_move_vector.connect(use_move_vector)
		if _aim:
			_aim.init(true)
			_aim.use_move_vector.connect(use_move_vector_aim)

func _load_all_data():
	if SaveManager != null:
		SaveManager.load_game()
		_money = SaveManager.save_data.get("money", 0)
		_type_body = SaveManager.get_player_stat("body_type", 1)
		_type_gun = SaveManager.get_player_stat("gun_type", 1)
		_color = SaveManager.get_player_stat("color_type", 0)
		_ammo_loadout = [
			clampi(SaveManager.get_player_stat("ammo_slot_0", LIGHT), 0, RICOCHET),
			clampi(SaveManager.get_player_stat("ammo_slot_1", PLASMA), 0, RICOCHET),
			clampi(SaveManager.get_player_stat("ammo_slot_2", MEDIUM), 0, RICOCHET)
		]
		_current_ammo_slot = clampi(SaveManager.get_player_stat("ammo_type", 0), 0, 2)
		_type_bullet = _ammo_loadout[_current_ammo_slot]

		select_type(_type_body, _type_gun, _color)
		money_changed.emit(_money)
		ammo_changed.emit(_current_ammo_slot)

func get_current_health() -> int: return _hp
func get_max_health() -> int: return _max_hp
func get_lives() -> int: return _lives
func get_money() -> int: return _money

func use_move_vector(move_vector: Vector2):
	var final_vector = -move_vector if _controls_inverted else move_vector
	velocity = final_vector * _speed
	if final_vector.length() > 0.01:
		rotation = final_vector.angle() + PI/2
	_handle_movement_sound(velocity)

# Функция для безопасного спавна пули (чтобы не пролетала сквозь стены вплотную)
func _get_safe_bullet_spawn_pos() -> Vector2:
	var start_pos = global_position # Центр танка
	var end_pos = _bullet_position.global_position # Кончик дула

	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(start_pos, end_pos)
	query.exclude = [self]
	query.collision_mask = 1 # Только стены

	var result = space_state.intersect_ray(query)
	if result:
		# Если дуло залезло в стену, спавним пулю прямо перед поверхностью стены
		return result.position - (end_pos - start_pos).normalized() * 5.0

	return end_pos

func fire_touch():
	if _shoot_timer.time_left > 0: return

	if AudioManager != null:
		var sound_type = _type_bullet
		if _type_bullet == HE:
			sound_type = MEDIUM
		elif _type_bullet == BOPS:
			sound_type = LIGHT
		elif _type_bullet == RICOCHET:
			sound_type = PLASMA
		AudioManager.play_bullet_sound(sound_type, global_position)

	var spawn_pos = _get_safe_bullet_spawn_pos()

	if _type_bullet == RICOCHET:
		if _ricochet_bullet_scene == null:
			return
		var rb = _ricochet_bullet_scene.instantiate()
		rb.global_position = spawn_pos
		rb.rotation_degrees = _gun.global_rotation_degrees
		get_parent().add_child(rb)
		var base_bullet_damage = 22
		var splash_base = 14
		var final_damage = int(base_bullet_damage * _base_damage_mult)
		var final_splash = int(splash_base * _base_damage_mult)
		rb.init(true, final_damage, final_splash, get_rid(), 2, false)
	else:
		var bullet = _bullet_scene.instantiate()
		bullet.global_position = spawn_pos
		bullet.rotation_degrees = _gun.global_rotation_degrees
		get_parent().add_child(bullet)

		var base_bullet_damage = 25
		match _type_bullet:
			PLASMA: base_bullet_damage = 25
			MEDIUM: base_bullet_damage = 40
			LIGHT: base_bullet_damage = 15
			HE: base_bullet_damage = 30
			BOPS: base_bullet_damage = 26

		var final_damage = int(base_bullet_damage * _base_damage_mult)
		bullet.init(_type_bullet, true, final_damage)

	if has_node("ShotAnimation"):
		$ShotAnimation.global_position = _bullet_position.global_position
		$ShotAnimation.play("Fire")

	_shoot_timer.start(_get_reload_time() * _base_rof_mult)

func _get_reload_time() -> float:
	var reload_base = 1.0
	match _type_gun:
		GUN_LIGHT: reload_base = 0.65
		GUN_MEDIUM: reload_base = 1.0
		GUN_HEAVY: reload_base = 1.8
		GUN_LMEDIUM: reload_base = 0.9
		GUN_MHEAVY: reload_base = 0.8
	var rof_color_bonus = 0.1 if _color == COLOR_GREEN else 0.05 if _color == COLOR_AZURE else 0.0
	return max(0.1, reload_base + rof_color_bonus)

func use_move_vector_aim(move_vector: Vector2):
	var desired_dir = -move_vector.normalized() if _controls_inverted else move_vector.normalized()
	var final_angle = desired_dir.angle() + PI/2
	var is_assist_on = SaveManager.get_setting("game", "aim_assist", true) if SaveManager else true

	if is_assist_on:
		var best_enemy = null
		var min_angle_diff = deg_to_rad(35.0)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if is_instance_valid(enemy) and _is_enemy_visible_for_assist(enemy) and _is_enemy_on_screen(enemy):
				var dir_to_enemy = (enemy.global_position - global_position).normalized()
				var angle_diff = abs(desired_dir.angle_to(dir_to_enemy))
				if angle_diff < min_angle_diff:
					min_angle_diff = angle_diff
					best_enemy = enemy
		if best_enemy:
			final_angle = (best_enemy.global_position - global_position).angle() + PI/2

	_gun.global_rotation = final_angle

func _is_enemy_visible_for_assist(enemy: Node) -> bool:
	var query = PhysicsRayQueryParameters2D.create(global_position, enemy.global_position)
	query.exclude = [self, enemy]; query.collision_mask = 1
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _is_enemy_on_screen(enemy: Node) -> bool:
	var screen_pos = get_viewport().get_canvas_transform() * enemy.global_position
	return get_viewport().get_visible_rect().has_point(screen_pos)

func _physics_process(delta):
	if _inverse_timer > 0:
		_inverse_timer -= delta
		if _inverse_timer <= 0:
			_controls_inverted = false

	if _joystick == null or not _joystick.get_is_joystick_active():
		var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if _controls_inverted: input_dir = -input_dir
		if input_dir.length() > 0:
			velocity = input_dir * _speed
			rotation = velocity.angle() + PI/2
			_handle_movement_sound(velocity)
		else:
			velocity = Vector2.ZERO
			_handle_movement_sound(Vector2.ZERO)

	if _aim != null and _aim.get_is_joystick_active() and _aim.move_vector.length() > 0.2:
		fire_touch()

	_check_base_buffs()
	move_and_slide()
	queue_redraw()

func _check_base_buffs():
	var in_range = false
	for b in get_tree().get_nodes_in_group("bases"):
		if b.get("type_base") == 0 and global_position.distance_to(b.global_position) <= b.get("_heal_radius"):
			apply_base_buffs(b.get("_damage_bonus"), b.get("_armor_bonus"), b.get("_rof_bonus"))
			in_range = true
			break
	if not in_range: apply_base_buffs(1.0, 0.0, 1.0)
	var hud = get_tree().get_first_node_in_group("hud")
	if hud: hud.set_buff_icon_visible(in_range)

func _on_ammo_selected(slot_idx: int):
	if slot_idx < 0 or slot_idx >= _ammo_loadout.size():
		return
	_current_ammo_slot = slot_idx
	_type_bullet = _ammo_loadout[_current_ammo_slot]
	if SaveManager != null:
		SaveManager.set_player_stat("ammo_type", _current_ammo_slot)
	ammo_changed.emit(_current_ammo_slot)

func get_ammo_loadout() -> Array[int]:
	return _ammo_loadout.duplicate()

func take_damage(damage: int):
	if _is_invulnerable: return
	super.take_damage(damage)
	health_changed.emit(_hp, _max_hp)
	# Даем инвул только если урон существенный (> 10)
	if _hp > 0 and damage > 10:
		_start_invulnerability(1.0)

func _destroy():
	_lives -= 1
	lives_changed.emit(_lives)
	if _lives > 0: _revive()
	else:
		if SaveManager: SaveManager.save_game()
		super._destroy()

func _revive():
	_hp = _max_hp; global_position = _start_position
	health_changed.emit(_hp, _max_hp)
	_update_damage_visuals(); _start_invulnerability(3.0)

func _start_invulnerability(duration: float):
	_is_invulnerable = true
	if _invul_tween: _invul_tween.kill()
	_invul_tween = create_tween().set_loops()
	_invul_tween.tween_property(self, "modulate:a", 0.3, 0.2)
	_invul_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	get_tree().create_timer(duration).timeout.connect(func():
		_is_invulnerable = false; if _invul_tween: _invul_tween.kill()
		modulate.a = 1.0
	)

func select_type(body_type: int, gun_type: int, color_type: int):
	_type_body = body_type; _type_gun = gun_type; _color = color_type
	_update_stats()
	_update_appearance()

func _update_stats():
	var hp_base = 100; var speed_base = 250; var dmg_mod = 1.0; var reload_base = 1.0; var armor_base = 0.0
	match _type_body:
		BODY_LIGHT: hp_base = 80; speed_base = 280; armor_base = -0.15
		BODY_MEDIUM: hp_base = 100; speed_base = 250; armor_base = 0.0
		BODY_HEAVY: hp_base = 250; speed_base = 200; armor_base = 0.3
		BODY_LMEDIUM: hp_base = 120; speed_base = 260; armor_base = 0.1
		BODY_MHEAVY: hp_base = 175; speed_base = 220; armor_base = 0.2
	match _type_gun:
		GUN_LIGHT: dmg_mod = 0.7; reload_base = 0.65
		GUN_MEDIUM: dmg_mod = 1.0; reload_base = 1.0
		GUN_HEAVY: dmg_mod = 2.5; reload_base = 1.8
		GUN_LMEDIUM: dmg_mod = 1.15; reload_base = 0.9
		GUN_MHEAVY: dmg_mod = 1.3; reload_base = 0.8
	var hp_bonus = 30 if _color == COLOR_GREEN else 5 if _color == COLOR_AZURE else 0
	var speed_bonus = -15 if _color == COLOR_GREEN else 20 if _color == COLOR_AZURE else 0
	_max_hp = hp_base + hp_bonus; _hp = _max_hp; _speed = speed_base + speed_bonus
	_damage = int(30 * dmg_mod)
	_armor = clamp(armor_base + (0.1 if _color == COLOR_GREEN else -0.1 if _color == COLOR_AZURE else 0.0), -0.9, 0.9)
	if _shoot_timer: _shoot_timer.wait_time = max(0.1, reload_base + (0.1 if _color == COLOR_GREEN else 0.05 if _color == COLOR_AZURE else 0.0))
	health_changed.emit(_hp, _max_hp)

func add_money(amount: int):
	_money += amount; money_changed.emit(_money)
	if SaveManager: SaveManager.save_game()

func _update_appearance():
	var color_f = "Color_A" if _color == COLOR_BROWN else "Color_B" if _color == COLOR_GREEN else "Color_C"
	var b_name = ["Hull_05", "Hull_02", "Hull_06", "Hull_01", "Hull_03"][_type_body]
	var g_name = ["Gun_01", "Gun_03", "Gun_08", "Gun_04", "Gun_07"][_type_gun]
	if _body: _body.texture = load("res://assets/future_tanks/PNG/Hulls_" + color_f + "/" + b_name + ".png")
	if _gun: _body.get_node("Gun").texture = load("res://assets/future_tanks/PNG/Weapon_" + color_f + "/" + g_name + ".png")

func take_heal(amount: int):
	_hp = min(_hp + amount, _max_hp); health_changed.emit(_hp, _max_hp); _update_damage_visuals()

func _apply_camera_fov():
	var cam = get_node_or_null("Camera2D") as Camera2D
	if cam and GameManager:
		var z = GameManager.get_camera_zoom_from_settings()
		cam.zoom = Vector2(z, z)

func _draw():
	if is_scope_on and _aim != null and _aim.get_is_joystick_active():
		var direction = Vector2(0, -1).rotated(_gun.global_rotation)
		if _type_bullet == RICOCHET:
			_draw_ricochet_scope_preview(direction.normalized())
			return

		var range_len = 650.0 # PLASMA default
		match _type_bullet:
			PLASMA: range_len = 650.0
			MEDIUM: range_len = 300.0
			LIGHT: range_len = 1000.0
			HE: range_len = 550.0
			BOPS: range_len = 1100.0

		draw_line(to_local(_bullet_position.global_position), to_local(_bullet_position.global_position + direction * range_len), Color(1, 0, 0, 0.5), 2.0)


func _is_wall_ricochet_preview(c: Object) -> bool:
	if c == null:
		return false
	if c is Player or c is Enemy:
		return false
	if c is StaticBody2D:
		return true
	if c.has_method("can_bullet_pass"):
		return not c.can_bullet_pass()
	var cls := c.get_class()
	return cls == "TileMap" or cls == "TileMapLayer"


## Предпросмотр пути рикошета (как у RicochetBullet): до 2 отскоков, дальность как MAX_RANGE снаряда.
func _draw_ricochet_scope_preview(dir: Vector2):
	const PREVIEW_MAX_RANGE := 2200.0
	const PLAYER_RICOCHET_BOUNCES := 2
	const RAY_CAP := 6000.0

	var pos_g := _bullet_position.global_position
	var remaining := PREVIEW_MAX_RANGE
	var bounces_left := PLAYER_RICOCHET_BOUNCES
	var last_local := to_local(pos_g)
	var col_main := Color(1.0, 0.25, 0.25, 0.62)
	var col_bounce := Color(0.35, 0.92, 1.0, 0.72)

	var space := get_world_2d().direct_space_state
	var safety := 0
	while safety < 12:
		safety += 1
		var reach := minf(remaining, RAY_CAP)
		var ray := PhysicsRayQueryParameters2D.create(pos_g, pos_g + dir * reach)
		ray.exclude = [get_rid()]
		var hit := space.intersect_ray(ray)

		if hit.is_empty():
			var end_g := pos_g + dir * reach
			draw_line(last_local, to_local(end_g), col_main if bounces_left == PLAYER_RICOCHET_BOUNCES else col_bounce, 2.0)
			return

		var hit_pos: Vector2 = hit.position
		var dist := pos_g.distance_to(hit_pos)
		if dist > remaining:
			var clip_g := pos_g + dir * remaining
			draw_line(last_local, to_local(clip_g), col_main if bounces_left == PLAYER_RICOCHET_BOUNCES else col_bounce, 2.0)
			return

		var collider: Object = hit.collider
		var hit_local := to_local(hit_pos)

		if collider is Enemy:
			draw_line(last_local, hit_local, col_main if bounces_left == PLAYER_RICOCHET_BOUNCES else col_bounce, 2.0)
			return

		if _is_wall_ricochet_preview(collider):
			draw_line(last_local, hit_local, col_main if bounces_left == PLAYER_RICOCHET_BOUNCES else col_bounce, 2.0)
			remaining = maxf(0.0, remaining - dist)
			if bounces_left <= 0:
				return
			bounces_left -= 1
			var n: Vector2 = hit.get("normal", Vector2.ZERO)
			if not (n is Vector2):
				n = Vector2.ZERO
			if n.length_squared() < 1e-10:
				return
			n = n.normalized()
			dir = dir.bounce(n)
			if dir.length_squared() < 1e-10:
				return
			dir = dir.normalized()
			pos_g = hit_pos + n * 5.0
			last_local = to_local(pos_g)
			continue

		draw_line(last_local, hit_local, col_main, 2.0)
		return

func _on_sfx_volume_changed(value: float):
	_normal_movement_volume = linear_to_db(value)
	if _moving_sound and _moving_sound.playing:
		_moving_sound.volume_db = _normal_movement_volume

func _toggle_scope(checkbox_value: bool):
	is_scope_on = checkbox_value
	queue_redraw()
