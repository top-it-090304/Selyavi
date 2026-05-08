extends Enemy

const PHASE2_HP_RATIO: float = 0.5
const ARTILLERY_SCENE: PackedScene = preload("res://scenes/Tank/ArtilleryTarget.tscn")
const FIRE_PATCH_SCRIPT = preload("res://scripts/FirePatch.gd")
const LATTICE_BULLET_SCRIPT = preload("res://scripts/Tank/InfernoLatticeBullet.gd")

var _phase2: bool = false
var _phase2_barrage_cd: float = 2.6
var _phase1_artillery_cd: float = 5.0

var _flame_burst_left: float = 0.0
var _flame_tick_accum: float = 0.0

var _hp_bar: ProgressBar
var _hp_bar_label: Label
var _flame_particles: CPUParticles2D
var _flame_beams: Array[Line2D] = []
const MAX_FLAME_BEAM_LINES: int = 7

var _flame_range: float = 260.0
var _flame_spread_deg: float = 16.0
var _flame_ray_count: int = 5
var _body_idle_modulate: Color = Color(1.0, 0.55, 0.28, 1.0)

var _phase2_pulse_tween: Tween
var _gun_home_local: Vector2 = Vector2.ZERO

# Логика огненного следа
var _fire_spawn_timer: float = 0.0
const FIRE_SPAWN_INTERVAL: float = 0.18

# ЛОГИКА РЕШЕТКИ (Phase 2)
var _is_executing_lattice: bool = false
var _lattice_cooldown: float = 0.0
var _p2_lattice_started: bool = false

# ЛОГИКА РЫВКА
var _dash_cooldown: float = 0.0
var _dash_timer: float = 0.0 # Время действия импульса
const DASH_CD_MAX: float = 7.0
const DASH_DURATION_P1: float = 0.4
const DASH_DURATION_P2: float = 0.22
const DASH_VELOCITY: float = 600.0

func _ready():
	_type_enemy = TypeEnemy.BOSS
	super._ready()

	_patrol_speed = int(_patrol_speed * 1.1 + 15)
	_chase_speed = int(_chase_speed * 1.1 + 20)
	_notice_range = 1080.0
	_attack_range = 430.0
	_flame_range = 450.0

	_fire_rate = 1.4
	_damage = int(round(_damage * 1.05))

	if _body:
		_body.texture = load("res://assets/future_tanks/PNG/Hulls_Color_D/Hull_06.png")
		_body.self_modulate = _body_idle_modulate
	if _gun:
		_gun.texture = load("res://assets/future_tanks/PNG/Weapon_Color_D/Gun_05.png")
		_gun.self_modulate = Color(1.0, 0.45, 0.2, 1.0)
		_gun_home_local = _gun.position

	# УМЕНЬШЕНИЕ КОЛЛИЗИИ: Делаем босса более "проходимым"
	var col = get_node_or_null("CollisionShape2D")
	if col and col.shape is CircleShape2D:
		col.shape.radius *= 0.75 # Уменьшаем физический размер на 25%

	_setup_flame_particles()
	_setup_flame_beams()
	_setup_flame_muzzle_animation()
	_setup_hp_bar()
	_flame_fx_idle()


func _burst_duration() -> float:
	return 1.1 if not _phase2 else 1.35


func _flame_tick_period() -> float:
	return 1.02 if not _phase2 else 0.95


func _flame_damage_tick() -> int:
	var mult: float = 0.65 if not _phase2 else 0.9
	var base = int(round(_damage * mult))
	return maxi(18 if not _phase2 else 26, base)


func _setup_flame_particles():
	_flame_particles = CPUParticles2D.new()
	_flame_particles.emitting = false
	_flame_particles.amount = 140
	_flame_particles.lifetime = 0.95
	_flame_particles.explosiveness = 0.06
	_flame_particles.randomness = 0.5
	_flame_particles.local_coords = true
	_flame_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_flame_particles.emission_sphere_radius = 18.0
	_flame_particles.direction = Vector2(0, -1)
	_flame_particles.spread = 42.0
	_flame_particles.initial_velocity_min = 220.0
	_flame_particles.initial_velocity_max = 420.0
	_flame_particles.gravity = Vector2(0, -8)
	_flame_particles.scale_amount_min = 0.4
	_flame_particles.scale_amount_max = 1.15
	_flame_particles.color = Color(1.0, 0.48, 0.08, 0.92)
	if _bullet_position:
		_bullet_position.add_child(_flame_particles)
		_flame_particles.position = Vector2.ZERO


func _setup_flame_beams():
	if _bullet_position == null:
		return
	for i in MAX_FLAME_BEAM_LINES:
		var ln := Line2D.new()
		ln.visible = false
		ln.z_index = 2
		ln.default_color = Color(1, 1, 1, 1)
		var wc := Curve.new()
		wc.add_point(Vector2(0.0, 1.0))
		wc.add_point(Vector2(1.0, 0.06))
		ln.width_curve = wc
		ln.width = 40.0
		var grad := Gradient.new()
		grad.add_point(0.0, Color(1.0, 0.92, 0.42, 0.92))
		grad.add_point(0.35, Color(1.0, 0.55, 0.08, 0.75))
		grad.add_point(1.0, Color(1.0, 0.12, 0.0, 0.0))
		ln.gradient = grad
		var mat := CanvasItemMaterial.new()
		mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		ln.material = mat
		_bullet_position.add_child(ln)
		_flame_beams.append(ln)


func _update_flame_beam_lines():
	if _bullet_position == null or _flame_beams.is_empty():
		return
	if _flame_burst_left <= 0.0:
		for ln in _flame_beams:
			ln.visible = false
		return
	var n: int = mini(_flame_beams.size(), _flame_ray_count)
	var spread: float = deg_to_rad(_flame_spread_deg)
	for i in range(_flame_beams.size()):
		var ln: Line2D = _flame_beams[i]
		if i >= n:
			ln.visible = false
			continue
		ln.visible = true
		var off := 0.0
		if n > 1:
			off = lerpf(-spread * 0.5, spread * 0.5, float(i) / float(n - 1))
		var tip := Vector2(0, -_flame_range).rotated(off)
		ln.clear_points()
		ln.add_point(Vector2.ZERO)
		ln.add_point(tip)
		var center := float(n - 1) * 0.5
		ln.width = clampf(46.0 - abs(float(i) - center) * 7.0, 16.0, 50.0)


func _setup_flame_muzzle_animation():
	if _shot_flash == null:
		return
	var sf = _shot_flash.sprite_frames
	if sf == null:
		return
	if sf.has_animation("Flame"):
		return
	sf.add_animation("Flame")
	var paths = [
		"res://assets/future_tanks/PNG/Effects/Explosion_B.png",
		"res://assets/future_tanks/PNG/Effects/Explosion_C.png",
		"res://assets/future_tanks/PNG/Effects/Explosion_D.png",
		"res://assets/future_tanks/PNG/Effects/Explosion_E.png",
	]
	for p in paths:
		var tex = load(p) as Texture2D
		if tex:
			sf.add_frame("Flame", tex, 0.07)
	sf.set_animation_loop("Flame", true)
	sf.set_animation_speed("Flame", 16.0)


func _flame_fx_idle():
	for ln in _flame_beams:
		ln.visible = false
	if _flame_particles:
		_flame_particles.emitting = false
	if _shot_flash:
		_shot_flash.stop()
		_shot_flash.visible = false


func _flame_fx_attacking():
	_update_flame_beam_lines()
	if _flame_particles:
		_flame_particles.emitting = true
	if _shot_flash:
		_shot_flash.visible = true
		if _shot_flash.sprite_frames and _shot_flash.sprite_frames.has_animation("Flame"):
			_shot_flash.play("Flame")
		elif _shot_flash.sprite_frames:
			_shot_flash.play("Fire")


func _setup_hp_bar():
	var canvas := CanvasLayer.new()
	add_child(canvas)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = _max_hp
	_hp_bar.value = _hp
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(520, 26)
	_hp_bar.anchor_left = 0.5
	_hp_bar.anchor_right = 0.5
	_hp_bar.anchor_top = 1.0
	_hp_bar.anchor_bottom = 0.1
	_hp_bar.offset_left = -260.0
	_hp_bar.offset_right = 260.0
	_hp_bar.offset_top = 22.0
	_hp_bar.offset_bottom = 50.0

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.04, 0.02, 0.45)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.9, 0.35, 0.08, 0.55)
	_hp_bar.add_theme_stylebox_override("background", bg)
	_set_bar_fill_color(Color(0.95, 0.28, 0.05, 0.65))
	canvas.add_child(_hp_bar)

	_hp_bar_label = Label.new()
	_hp_bar_label.text = "ИНФЕРНО"
	_hp_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_bar_label.add_theme_color_override("font_color", Color(1.0, 0.55, 0.2, 0.85))
	_hp_bar_label.custom_minimum_size = Vector2(520, 20)
	_hp_bar_label.anchor_left = 0.5
	_hp_bar_label.anchor_right = 0.5
	_hp_bar_label.anchor_top = 1.0
	_hp_bar_label.anchor_bottom = 0.1
	_hp_bar_label.offset_left = -260.0
	_hp_bar_label.offset_right = 260.0
	_hp_bar_label.offset_top = 0.0
	_hp_bar_label.offset_bottom = 22.0
	canvas.add_child(_hp_bar_label)


func _set_bar_fill_color(color: Color):
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	if _hp_bar:
		_hp_bar.add_theme_stylebox_override("fill", fill)


func take_damage(damage: int):
	if _is_invulnerable:
		return
	super.take_damage(damage)
	if _hp_bar:
		_hp_bar.value = _hp
	if not _phase2 and float(_hp) / float(_max_hp) <= PHASE2_HP_RATIO:
		_enter_phase2()


func _play_body_hit_flash():
	if _body:
		if _hit_flash_tween and _hit_flash_tween.is_running(): _hit_flash_tween.kill()
		_hit_flash_tween = create_tween()
		_hit_flash_tween.tween_property(_body, "self_modulate", Color(4.2, 3.8, 2.5, 1.0), 0.05)
		_hit_flash_tween.tween_property(_body, "self_modulate", _body_idle_modulate, 0.08)


func _enter_phase2():
	if _phase2:
		return
	_phase2 = true
	_is_invulnerable = true
	_p2_lattice_started = false

	if _hp_bar_label:
		_hp_bar_label.text = "ИНФЕРНО — В ЯРОСТИ"
		_hp_bar_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.18, 0.95))
	_set_bar_fill_color(Color(1.0, 0.38, 0.06, 0.78))

	if _body:
		var tw := create_tween()
		tw.tween_property(_body, "self_modulate", Color(1.5, 0.32, 0.08, 1.0), 0.45)

	await get_tree().create_timer(0.85).timeout
	if not is_instance_valid(self) or is_queued_for_deletion(): return

	_apply_phase2_stats()
	_is_invulnerable = false
	_start_phase2_pulse()


func _apply_phase2_stats():
	_fire_rate *= 0.8
	_flame_range = 500.0
	_flame_spread_deg = 27.0
	_flame_ray_count = 7
	_damage = int(round(_damage * 1.08))
	_body_idle_modulate = Color(1.0, 0.35, 0.12, 1.0)
	if _body: _body.self_modulate = _body_idle_modulate


func _start_phase2_pulse():
	if _body == null: return
	if _phase2_pulse_tween and _phase2_pulse_tween.is_running(): _phase2_pulse_tween.kill()
	_phase2_pulse_tween = create_tween().set_loops()
	_phase2_pulse_tween.tween_property(_body, "self_modulate", Color(1.55, 0.22, 0.06, 1.0), 0.26)
	_phase2_pulse_tween.tween_property(_body, "self_modulate", _body_idle_modulate, 0.26)


func _move_enemy(delta: float):
	if _dash_timer > 0:
		var dash_dir = Vector2.ZERO
		if _nav2d and not _nav2d.is_navigation_finished():
			dash_dir = (_nav2d.get_next_path_position() - global_position).normalized()
		else:
			var target = _get_current_target()
			if is_instance_valid(target):
				dash_dir = global_position.direction_to(target.global_position)

		velocity = dash_dir * DASH_VELOCITY
		move_and_slide()

		# Анти-застревание: Если во время рывка скорость упала почти до нуля
		if _dash_timer < 0.3 and get_real_velocity().length() < 150.0:
			_dash_timer = 0

		if velocity.length() > 15.0:
			rotation = lerp_angle(rotation, velocity.angle() + PI / 2, delta * 12.0)
		return

	if _is_executing_lattice:
		velocity = velocity.move_toward(Vector2.ZERO, delta * 400.0)
		return

	_speed_limit_mult = 1.0
	var current_speed = _chase_speed if (_current_state == State.CHASE or _type_enemy == TypeEnemy.SCOUT) else _patrol_speed
	if _nav2d == null or _type_enemy == TypeEnemy.STATIONARY or _type_enemy == TypeEnemy.ARTILLERY or current_speed <= 0:
		velocity = velocity.move_toward(Vector2.ZERO, delta * 600.0); return
	var target = _get_current_target()
	var nav_dir = Vector2.ZERO
	if not _nav2d.is_navigation_finished():
		nav_dir = (_nav2d.get_next_path_position() - global_position).normalized()
	if nav_dir.length_squared() < 0.0001 and is_instance_valid(target) and target is Node2D:
		var to_tgt = (target as Node2D).global_position - global_position
		if to_tgt.length_squared() > 25.0: nav_dir = to_tgt.normalized()
	if (Engine.get_physics_frames() + _logic_frame_offset) % 2 == 0:
		_cached_avoidance = _compute_ally_avoidance(nav_dir)
	_smoothed_avoidance = _smoothed_avoidance.lerp(_cached_avoidance, delta * 12.0)
	var in_attack_range = false
	if is_instance_valid(target):
		var dist = global_position.distance_to(target.global_position)
		if dist <= _attack_range and _target_in_sight and _roll_out_timer <= 0: in_attack_range = true
	var final_dir = _smoothed_avoidance * 0.3 if in_attack_range else (nav_dir + _smoothed_avoidance * (1.2 if _type_enemy == TypeEnemy.BOSS else 0.7)).normalized()
	velocity = velocity.lerp(final_dir * current_speed * _speed_limit_mult, delta * 9.0)
	if velocity.length() > 15.0: rotation = lerp_angle(rotation, velocity.angle() + PI / 2, delta * 6.0)


func _physics_process(delta: float):
	super._physics_process(delta)

	if _dash_cooldown > 0: _dash_cooldown -= delta
	if _dash_timer > 0:
		_dash_timer -= delta
		_spawn_tracks_fire()

	if _lattice_cooldown > 0: _lattice_cooldown -= delta

	# Рывок доступен в обеих фазах (если не занят Сеткой)
	if _dash_cooldown <= 0 and is_instance_valid(_player) and not _is_executing_lattice:
		if global_position.distance_to(_player.global_position) > 550.0:
			_perform_dash()

	if _phase2:
		# Фаза 2: Сетка
		if not _p2_lattice_started:
			_p2_lattice_started = true
			_start_lattice_attack()
		elif _lattice_cooldown <= 0 and not _is_executing_lattice and is_instance_valid(_player):
			_start_lattice_attack()

		_phase2_barrage_cd -= delta
		if _phase2_barrage_cd <= 0.0:
			_phase2_barrage_cd = 4.5
			_try_phase2_barrage()

		if velocity.length() > 30.0 and _dash_timer <= 0:
			_fire_spawn_timer -= delta
			if _fire_spawn_timer <= 0:
				_fire_spawn_timer = FIRE_SPAWN_INTERVAL
				_spawn_tracks_fire()
	else:
		_phase1_artillery_cd -= delta
		if _phase1_artillery_cd <= 0:
			_phase1_artillery_cd = 7.0
			_try_phase1_artillery()

	var period := _flame_tick_period()
	if _flame_burst_left > 0.0:
		_flame_burst_left -= delta
		_flame_tick_accum += delta
		while _flame_tick_accum >= period:
			_flame_tick_accum -= period
			_do_flame_damage_tick()
		if _gun: _gun.position = _gun_home_local + Vector2(randf_range(-3.0, 3.0), randf_range(-5.0, 2.0))
		_update_flame_beam_lines()
	if _flame_burst_left <= 0.0:
		if _gun: _gun.position = _gun_home_local
		_flame_fx_idle()

func _perform_dash():
	_dash_cooldown = DASH_CD_MAX
	var duration = DASH_DURATION_P2 if _phase2 else DASH_DURATION_P1
	_dash_timer = duration

	if is_instance_valid(_player):
		if _body:
			var tw = create_tween()
			tw.tween_property(_body, "self_modulate", Color(5, 2, 1, 1), 0.1)
			tw.tween_property(_body, "self_modulate", _body_idle_modulate, duration)

func _start_lattice_attack():
	_is_executing_lattice = true
	_lattice_cooldown = 14.0

	if _gun:
		var tw = create_tween()
		tw.tween_property(_gun, "rotation_degrees", _gun.rotation_degrees + 1080, 1.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN_OUT)
		await tw.finished

	_spawn_lattice()
	_is_executing_lattice = false

func _spawn_lattice():
	if not is_instance_valid(_player) or is_queued_for_deletion(): return

	var p_pos = _player.global_position

	# АДАПТИВНОСТЬ: Рассчитываем дистанцию спавна на основе вьюпорта
	var view_size = get_viewport_rect().size
	var zoom = 1.0
	if get_viewport().get_camera_2d():
		zoom = get_viewport().get_camera_2d().zoom.x

	var spawn_dist = (max(view_size.x, view_size.y) / zoom) * 0.75
	var spacing = 240.0
	var count = 12

	# СВЕРХУ (Вниз)
	for i in range(count):
		var x = p_pos.x + (i - count/2.0) * spacing
		_create_lattice_bullet(Vector2(x, p_pos.y - spawn_dist), Vector2.DOWN)

	# СПРАВА (Влево)
	for i in range(count):
		var y = p_pos.y + (i - count/2.0) * spacing
		_create_lattice_bullet(Vector2(p_pos.x + spawn_dist, y), Vector2.LEFT)

func _create_lattice_bullet(pos: Vector2, dir: Vector2):
	var b = Area2D.new()
	b.set_script(LATTICE_BULLET_SCRIPT)
	get_parent().add_child(b)
	b.init(pos, dir, 25)

func _spawn_tracks_fire():
	var track_offsets = [Vector2(-35, 0), Vector2(35, 0)]
	for offset in track_offsets:
		var patch = Node2D.new(); patch.set_script(FIRE_PATCH_SCRIPT); patch.global_position = global_position + offset.rotated(rotation)
		get_parent().add_child(patch)


func _fire_at_pos(_pos: Vector2):
	if _shoot_timer.time_left > 0.0 or _flame_burst_left > 0.0 or _is_executing_lattice: return
	if AudioManager: AudioManager.play_flamethrower_sound(global_position)
	_flame_burst_left = _burst_duration(); _flame_tick_accum = _flame_tick_period(); _flame_fx_attacking()
	_shoot_timer.start(_burst_duration() + _fire_rate)


func _do_flame_damage_tick():
	if _bullet_position == null: return
	var tgt = _get_current_target(); if not is_instance_valid(tgt) or not (tgt is Node2D): return
	var origin := _bullet_position.global_position; var target_pt: Vector2 = (tgt as Node2D).global_position
	var base_ang: float = (target_pt - origin).angle(); var dmg := _flame_damage_tick(); var space := get_world_2d().direct_space_state
	var exclude: Array[RID] = [get_rid()]; var count := _flame_ray_count; var spread := deg_to_rad(_flame_spread_deg); var damaged_ids: Dictionary = {}
	for i in range(count):
		var off := 0.0; if count > 1: off = lerpf(-spread * 0.5, spread * 0.5, float(i) / float(count - 1))
		var ang := base_ang + off; var dir := Vector2.from_angle(ang); var to := origin + dir * _flame_range
		var q := PhysicsRayQueryParameters2D.create(origin, to); q.exclude = exclude; q.collision_mask = 3; q.collide_with_areas = true; q.collide_with_bodies = true
		var hit: Dictionary = space.intersect_ray(q); if hit.is_empty(): continue
		var col: Variant = hit.get("collider"); if col == null or not (col is Node): continue
		var nid = (col as Node).get_instance_id(); if damaged_ids.has(nid): continue
		damaged_ids[nid] = true
		if col is Player: (col as Player).take_damage(dmg, true); (col as Player).apply_burn(1.5)
		elif col is Base: (col as Base).take_damage(dmg)

func _try_phase1_artillery():
	if ARTILLERY_SCENE == null: return
	var tgt = _get_current_target(); if not is_instance_valid(tgt) or not (tgt is Node2D): return
	_spawn_phase_shell(tgt.global_position, 30, 140.0, 1.8, false)

func _try_phase2_barrage():
	if not _phase2 or ARTILLERY_SCENE == null: return
	var tgt = _get_current_target()
	if not is_instance_valid(tgt) or not (tgt is Node2D): return
	var center: Vector2 = (tgt as Node2D).global_position
	for i in range(6):
		var ang = TAU * float(i) / 6.0; var pos = center + Vector2.from_angle(ang) * 140.0
		_spawn_phase_shell(pos, 40, 120.0, 1.5, true)
	_spawn_phase_shell(center, 40, 155.0, 1.75, true)

func _spawn_phase_shell(pos: Vector2, dmg: int, radius: float, duration: float, is_p2: bool):
	var shell = ARTILLERY_SCENE.instantiate()
	shell.global_position = pos + Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0))
	shell.set("_damage", dmg); shell.set("_radius", radius); shell.set("_duration", duration)
	if "_is_inferno_phase2" in shell: shell.set("_is_inferno_phase2", is_p2)
	get_parent().add_child(shell)

func _destroy():
	if _phase2_pulse_tween and _phase2_pulse_tween.is_running(): _phase2_pulse_tween.kill()
	_flame_fx_idle(); super._destroy()
