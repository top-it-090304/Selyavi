extends Enemy
class_name TwinBoss

enum TwinVariant { MELEE, RANGED }
enum RamState { NORMAL, PREPARING, CHARGING, STUNNED, RECOVERING }
enum SurvivorAttack { CLUSTER, FIRE, VOLLEY, ELECTRIC_PAIR, MINI_INSTALLATION }

const RAM_PREPARE_TIME: float = 1.0
const RAM_SPEED: float = 650.0
const RAM_DISTANCE: float = 650.0
const RAM_MIN_DISTANCE: float = 250.0
const RAM_MAX_START_DISTANCE: float = 550.0
const RAM_COOLDOWN: float = 10.0
const PHASE2_RAM_COOLDOWN: float = 7.0
const PHASE2_RAM_STUN: float = 2.0
const RAM_APPROACH_MAX_DISTANCE: float = 950.0
const RAM_APPROACH_MIN_TRAVEL: float = 200.0
const RAM_DAMAGE: int = 40
const RAM_SHOTS: int = 5
const RAM_SHOT_INTERVAL: float = 0.16
const RAM_PLAYER_STUN: float = 3.0
const RAM_WALL_STUN: float = 5.0
const RAM_BARREL_ANIMATION_TIME: float = 0.2
const RAM_BARREL_RETRACT: float = 76.0
const RAM_WARNING_BLINK_HZ: float = 5.0
const RAM_SECOND_DISTANCE: float = RAM_DISTANCE
const RAM_SECOND_PREPARE_TIME: float = 0.5
const MINI_RAM_HP_RATIO: float = 0.35
const MINI_RAM_COUNT: int = 4
const MINI_RAM_DISTANCE: float = 300.0
const MINI_RAM_PREPARE_TIME: float = 0.5
const MINI_RAM_INTERVAL: float = 0.5
const MINI_RAM_COOLDOWN: float = 2.0
const MINI_RAM_APPROACH_DISTANCE: float = MINI_RAM_COUNT * MINI_RAM_DISTANCE

const PHASE2_HP_RATIO: float = 0.5
const PHASE2_AURA_RADIUS: float = 160.0
const PHASE2_AURA_DAMAGE: int = 15
const PHASE2_AURA_HIT_INTERVAL: float = 1.0
const PHASE2_AURA_GROW_TIME: float = 0.75
const MELEE_BULLET_RANGE: float = 600.0
const AURA_PARTICLE_MARGIN: float = 12.0
const RANGED_TRANSFORM_TIME: float = 2.0
const RANGED_PHASE2_FIRE_RATE: float = 0.9
const RANGED_SHIELD_DISTANCE: float = 300.0
const RANGED_TRANSFORM_SHIELD_ANGLE: float = PI / 180.0 * 25.0
const RANGED_DISTANT_SHIELD_SPREAD: float = PI / 180.0 * 20.0
const SHIELD_SCRIPT = preload("res://scripts/Tank/TwinShield.gd")
const HEAL_PLUS_TEXTURE = preload("res://assets/BaseAssets/plus.png")
const SPECIAL_BULLET_SCRIPT = preload("res://scripts/Tank/TwinSpecialBullet.gd")
const FIRE_TRAIL_SCRIPT = preload("res://scripts/Tank/TwinFireTrail.gd")
const ENERGY_LINKS_SCRIPT = preload("res://scripts/Tank/TwinEnergyLinks.gd")
const MINI_INSTALLATION_SCENE = preload("res://scenes/Tank/TwinMiniInstallation.tscn")
const MINI_INSTALLATION_DISTANCE: float = 600.0
const MINI_INSTALLATION_SPREAD: float = PI / 180.0 * 20.0
const MINI_INSTALLATION_LIMIT: int = 3
const STATION_PLACEMENT_SCRIPT = preload("res://scripts/Tank/TwinStationPlacement.gd")
const RANGED_HIDDEN_HEAL_DELAY: float = 5.0
const RANGED_PROJECTILE_SPEED: float = 420.0
const SURVIVOR_FIRE_ANGLE: float = 0.2
const VOLLEY_SPREAD: float = PI / 180.0 * 5.0
const NAV_RETURN_SCRIPT = preload("res://scripts/Tank/TwinNavigationReturn.gd")
const NAV_RETURN_TOLERANCE: float = 2.0
const NAV_RETURN_RETRY: float = 0.6

const HEAL_RATE: float = 7.0
const LINE_DAMAGE: int = 20
const LINE_DAMAGE_COOLDOWN: float = 1.0
const LINE_HIT_RADIUS: float = 40.0
const THREAD_ANIMATION_FPS: float = 24.0
const THREAD_BEND_AMPLITUDE: float = 16.0
const THREAD_SEGMENT_LENGTH: float = 80.0
const THREAD_TEXTURES: Array[Texture2D] = [
	preload("res://assets/effects/twins/tiles/beam_tile_01.png"),
	preload("res://assets/effects/twins/tiles/beam_tile_02.png"),
	preload("res://assets/effects/twins/tiles/beam_tile_04.png"),
	preload("res://assets/effects/twins/tiles/beam_tile_03.png"),
]

# Боевой стиль близнеца. Задаётся в инспекторе или кодом до add_child.
@export var variant: TwinVariant = TwinVariant.MELEE
# Ссылка на второго близнеца — можно назначить в редакторе для ручной расстановки.
@export var twin_path: NodePath
var twin: TwinBoss = null

var _keep_distance: float = 460.0 # Для дальнобойного: дистанция, на которой он кайтит
var _retreating: bool = false
var _retreat_repath_timer: float = 0.0
var _heal_accum: float = 0.0
var _line_damage_cooldown: float = 0.0
var _thread_line: Line2D
var _thread_animation_time: float = 0.0
var _thread_bend_time: float = 0.0
var _thread_frame: int = 0
var _hp_bar: ProgressBar
var _hp_bar_label: Label
var _base_tint: Color = Color.WHITE
var _fire_left_barrel: bool = true
var _ram_state: RamState = RamState.NORMAL
var _ram_time: float = 0.0
var _ram_cooldown: float = 5.0 # Задержка до первого тарана.
var _has_rammed_once: bool = false
var _ram_direction: Vector2 = Vector2.UP
var _ram_remaining: float = 0.0
var _ram_speed: float = RAM_SPEED
var _ram_shots_fired: int = 0
var _ram_shot_time: float = 0.0
var _ram_stun_duration: float = 0.0
var _ram_warning: Line2D
var _ram_warning_cast: ShapeCast2D
var _ram_warning_distance: float = RAM_DISTANCE
var _ram_warning_base_modulate: Color = Color.WHITE
var _phase2_active: bool = false
var _aura_hit_cooldown: float = 0.0
var _aura_shape: CircleShape2D
var _ranged_twin_lost: bool = false
var _ram_second_dash: bool = false
var _ram_charge_distance: float = RAM_DISTANCE
var _ram_prepare_duration: float = RAM_PREPARE_TIME
var _mini_ram_active: bool = false
var _mini_ram_dash_index: int = 0
var _mini_ram_mode_active: bool = false
var _aura_growth: float = 0.0
var _aura_particles: CPUParticles2D
var _ranged_transforming: bool = false
var _ranged_transform_elapsed: float = 0.0
var _ranged_transform_start_hp: int = 0
var _ranged_body_rotation: float = 0.0
var _ranged_plus_time: float = 0.0
var _ranged_heal_effect: Node2D
var _ranged_shot_count: int = 0
var _ranged_transform_shields_fired: bool = false
var _melee_twin_lost: bool = false
var _ranged_volley_left: int = 0
var _ranged_volley_time: float = 0.0
var _ranged_volley_interval: float = 0.0
var _ranged_fire_trail: Node2D
var _nav_return_active: bool = false
var _nav_return_path: PackedVector2Array
var _nav_return_waypoint: int = 0
var _nav_return_retry: float = 0.0
var _nav_return_map_iteration: int = 0
var _nav_return_last_position: Vector2
var _nav_return_stuck_time: float = 0.0
var _ranged_unseen_time: float = 0.0
var _ranged_hidden_heal_accum: float = 0.0
var _station_replan_time: float = 0.0

func _enter_tree():
	add_to_group("twin_bosses")

func _ready():
	_type_enemy = TypeEnemy.BOSS
	super._ready()
	_apply_variant_stats()
	_update_damage_visuals()
	_setup_thread_line()
	_apply_variant_tint()
	_setup_ram_warning()
	_setup_aura_particles()
	_setup_hp_bar()
	_resolve_twin_path()
	_auto_pair_with_sibling()
	_watch_ranged_twin()
	_watch_melee_twin()
	if is_instance_valid(twin):
		twin._watch_ranged_twin()
		twin._watch_melee_twin()

func _watch_ranged_twin():
	if variant != TwinVariant.MELEE or not is_instance_valid(twin): return
	if twin.variant != TwinVariant.RANGED: return
	if not twin.enemy_died.is_connected(_on_ranged_twin_lost):
		twin.enemy_died.connect(_on_ranged_twin_lost)

func _on_ranged_twin_lost(_type: int):
	_ranged_twin_lost = true
	_update_phase2()
	_update_mini_ram_mode()

func _watch_melee_twin():
	if variant != TwinVariant.RANGED or not is_instance_valid(twin): return
	if twin.variant != TwinVariant.MELEE: return
	if not twin.enemy_died.is_connected(_on_melee_twin_lost):
		twin.enemy_died.connect(_on_melee_twin_lost)

func _on_melee_twin_lost(_type: int):
	_melee_twin_lost = true

# Для ручной расстановки в редакторе: связывает пару по назначенному NodePath.
func _resolve_twin_path():
	if twin != null or twin_path.is_empty(): return
	var other = get_node_or_null(twin_path)
	if other is TwinBoss:
		twin = other
		if other.twin == null: other.twin = self

# Если пара не указана явно через Twin Path — ищем свободного близнеца по всей
# сцене и связываемся с ним сами. Благодаря этому достаточно просто поставить
# два TwinBoss на карту, ничего не настраивая руками.
func _auto_pair_with_sibling():
	if twin != null: return
	for other in get_tree().get_nodes_in_group("twin_bosses"):
		if other == self or not (other is TwinBoss): continue
		if other.twin == null:
			twin = other
			other.twin = self
			return

func _apply_variant_stats():
	match variant:
		TwinVariant.MELEE:
			# Штурмовик: быстрый, живучий, давит в упор частыми выстрелами.
			_max_hp = 600; _hp = _max_hp
			_damage = 24
			_fire_rate = 0.55
			_spread = 0.18
			_patrol_speed = 150
			_chase_speed = 210
			_notice_range = 950.0
			_attack_range = 400.0
			# Не срезаем поворот раньше вершины пути у границы навигации.
			if _nav2d: _nav2d.path_desired_distance = 2.0
		TwinVariant.RANGED:
			# Егерь: хрупче и медленнее, но бьёт больно, точно и издалека.
			_max_hp = 400; _hp = _max_hp
			_damage = 46
			_fire_rate = 1.5
			_spread = 0.04
			_patrol_speed = 80
			_chase_speed = 70
			_notice_range = 1100.0
			_attack_range = 720.0
			_keep_distance = 460.0
	if _shoot_timer: _shoot_timer.wait_time = _fire_rate

func _apply_variant_tint():
	if _body == null: return

	if variant == TwinVariant.MELEE:
		if _gun: _gun.texture = load("res://assets/future_tanks/PNG/Weapon_Color_D_256X256/Gun_06_B.png")
		# Красная (Color_D) текстура — уже используется по умолчанию, дополнительно
		# насыщаем её через self_modulate, чтобы турель и корпус были одинаково красными.
		_base_tint = Color(1.4, 0.55, 0.5)
	else:
		# Меняем саму текстуру на лазурную линейку (Color_C) — просто тонировать
		# красную текстуру в синий не выйдет (умножение не добавляет недостающий канал).
		_body.texture = load("res://assets/future_tanks/PNG/Hulls_Color_C/Hull_01.png")
		if _gun: _gun.texture = load("res://assets/future_tanks/PNG/Weapon_Color_D_256X256/Gun_08.png")
		_base_tint = Color(0.6, 0.9, 1.3)

	_body.self_modulate = _base_tint
	if _gun:
		_gun.self_modulate = _base_tint
		_gun.offset = Vector2(0, -22) if variant == TwinVariant.MELEE else Vector2.ZERO
		var barrels = _gun.get_node_or_null("Barrels") as Sprite2D
		if barrels:
			barrels.visible = variant == TwinVariant.MELEE
			barrels.self_modulate = _base_tint
	if _bullet_position:
		_bullet_position.position = Vector2(-9, -121) if variant == TwinVariant.MELEE else Vector2(0, -111)

# Переопределяем: базовый Tank.gd сбрасывает "modulate" в белый после вспышки,
# из-за чего наш цвет по варианту (self_modulate) слетал бы, если б красили тем же
# свойством. Красим/мигаем через self_modulate и возвращаем не белый, а цвет варианта.
func _play_body_hit_flash():
	if _body == null: return
	if _hit_flash_tween != null and _hit_flash_tween.is_running():
		_hit_flash_tween.kill()
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(_body, "self_modulate", Color(4.5, 4.5, 4.5, 1.0), 0.05)
	_hit_flash_tween.tween_property(_body, "self_modulate", _base_tint, 0.07)

func _update_damage_visuals():
	if variant != TwinVariant.MELEE:
		super._update_damage_visuals()
		return
	if not is_instance_valid(_smoke_particles) or _max_hp <= 0: return
	var damage_progress = clampf((1.0 - float(_hp) / _max_hp) / (1.0 - PHASE2_HP_RATIO), 0.0, 1.0)
	_smoke_particles.emitting = _hp > 0 and damage_progress > 0.0
	# Постоянное число частиц не перезапускает дым при каждом новом попадании.
	if _smoke_particles.amount != 36: _smoke_particles.amount = 36
	_smoke_particles.color = Color(1.0, 1.0, 1.0, lerpf(0.05, 0.65, damage_progress))
	_smoke_particles.scale_amount_min = lerpf(0.1, 0.55, damage_progress)
	_smoke_particles.scale_amount_max = lerpf(0.2, 1.25, damage_progress)

func _setup_hp_bar():
	var canvas = CanvasLayer.new()
	add_child(canvas)

	var bar_color = Color(0.85, 0.3, 0.25) if variant == TwinVariant.MELEE else Color(0.3, 0.55, 0.9)
	var boss_name = "ШТУРМОВИК" if variant == TwinVariant.MELEE else "ЕГЕРЬ"
	# Разносим полосы двух близнецов по вертикали, чтобы не накладывались друг на
	# друга — оба видны на экране одновременно (в отличие от одиночных боссов).
	var row_offset = 0.0 if variant == TwinVariant.MELEE else 50.0

	_hp_bar = preload("res://scripts/BossHealthBar.gd").new()
	_hp_bar.max_value = _max_hp
	_hp_bar.value = _hp
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(420, 22)
	_hp_bar.anchor_left = 0.5; _hp_bar.anchor_right = 0.5; _hp_bar.anchor_top = 1.0; _hp_bar.anchor_bottom = 0.1
	_hp_bar.offset_left = -210.0; _hp_bar.offset_right = 210.0
	_hp_bar.offset_top = 22.0 + row_offset; _hp_bar.offset_bottom = 46.0 + row_offset

	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.07, 0.07, 0.07, 0.4)
	bg.set_border_width_all(2)
	bg.border_color = bar_color.lightened(0.2)
	_hp_bar.add_theme_stylebox_override("background", bg)
	var fill = StyleBoxFlat.new()
	fill.bg_color = bar_color
	_hp_bar.add_theme_stylebox_override("fill", fill)
	canvas.add_child(_hp_bar)

	_hp_bar_label = Label.new()
	_hp_bar_label.text = boss_name
	_hp_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_bar_label.add_theme_color_override("font_color", bar_color.lightened(0.3))
	_hp_bar_label.custom_minimum_size = Vector2(420, 20)
	_hp_bar_label.anchor_left = 0.5; _hp_bar_label.anchor_right = 0.5; _hp_bar_label.anchor_top = 1.0; _hp_bar_label.anchor_bottom = 0.1
	_hp_bar_label.offset_left = -210.0; _hp_bar_label.offset_right = 210.0
	_hp_bar_label.offset_top = 0.0 + row_offset; _hp_bar_label.offset_bottom = 22.0 + row_offset
	canvas.add_child(_hp_bar_label)

func take_damage(damage: int):
	super.take_damage(damage)
	if _hp_bar: _hp_bar.value = _hp
	_update_phase2()
	if variant == TwinVariant.MELEE: _update_mini_ram_mode()

func _update_phase2():
	if _phase2_active or _hp <= 0: return
	if variant == TwinVariant.RANGED:
		if float(_hp) / _max_hp <= PHASE2_HP_RATIO: _begin_ranged_transformation()
		return
	if float(_hp) / float(_max_hp) <= PHASE2_HP_RATIO:
		_phase2_active = true
		if _has_rammed_once and _ram_state == RamState.NORMAL:
			_ram_cooldown = maxf(0.0, _ram_cooldown - (RAM_COOLDOWN - PHASE2_RAM_COOLDOWN))
		if _ram_state == RamState.STUNNED:
			var elapsed = _ram_stun_duration - _ram_time
			_ram_stun_duration = PHASE2_RAM_STUN
			_ram_time = maxf(0.0, PHASE2_RAM_STUN - elapsed)
		_aura_shape = CircleShape2D.new()
		_aura_shape.radius = 0.0
		queue_redraw()

func _process_phase2_aura(delta: float):
	if variant != TwinVariant.MELEE or not _phase2_active or _hp <= 0: return
	if _aura_growth < 1.0:
		_aura_growth = minf(1.0, _aura_growth + delta / PHASE2_AURA_GROW_TIME)
		_aura_shape.radius = PHASE2_AURA_RADIUS * smoothstep(0.0, 1.0, _aura_growth)
		queue_redraw()
	# Область следует за позицией босса, сохраняя своё направление в мировых координатах.
	_aura_particles.global_transform = Transform2D(0.0, global_scale.abs(), 0.0, global_position)
	_aura_particles.emission_sphere_radius = maxf(0.0, _aura_shape.radius - AURA_PARTICLE_MARGIN)
	_aura_particles.emitting = _aura_shape.radius > AURA_PARTICLE_MARGIN
	_aura_hit_cooldown = maxf(0.0, _aura_hit_cooldown - delta)
	if _aura_hit_cooldown > 0.0 or _aura_shape.radius <= 0.0: return
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = _aura_shape
	query.transform = global_transform
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	for hit in get_world_2d().direct_space_state.intersect_shape(query, 64):
		if hit.collider is Player and not hit.collider.is_queued_for_deletion():
			hit.collider.take_damage(PHASE2_AURA_DAMAGE)
			_aura_hit_cooldown = PHASE2_AURA_HIT_INTERVAL
			break

func _setup_aura_particles():
	if variant != TwinVariant.MELEE: return
	_aura_particles = CPUParticles2D.new()
	_aura_particles.name = "AuraParticles"
	_aura_particles.emitting = false
	_aura_particles.amount = 32
	_aura_particles.lifetime = 0.6
	_aura_particles.lifetime_randomness = 0.5
	_aura_particles.local_coords = true
	_aura_particles.top_level = true
	_aura_particles.z_index = -1
	_aura_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_aura_particles.emission_sphere_radius = 0.0
	_aura_particles.direction = Vector2.UP
	_aura_particles.spread = 70.0
	_aura_particles.gravity = Vector2.ZERO
	_aura_particles.initial_velocity_min = 4.0
	_aura_particles.initial_velocity_max = 10.0
	_aura_particles.scale_amount_min = 0.45
	_aura_particles.scale_amount_max = 1.0
	_aura_particles.color = Color(1.0, 0.06, 0.03, 1.0)
	var fade = Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.8))
	fade.add_point(0.15, Color.WHITE)
	fade.set_color(fade.get_point_count() - 1, Color(1, 1, 1, 0))
	_aura_particles.color_ramp = fade
	var dot_gradient = Gradient.new()
	dot_gradient.set_color(0, Color.WHITE)
	dot_gradient.set_color(1, Color(1, 1, 1, 0))
	var dot = GradientTexture2D.new()
	dot.width = 8
	dot.height = 8
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	dot.gradient = dot_gradient
	_aura_particles.texture = dot
	add_child(_aura_particles)
	_aura_particles.global_transform = Transform2D(0.0, global_scale.abs(), 0.0, global_position)

func _draw():
	if variant != TwinVariant.MELEE or not _phase2_active or _hp <= 0: return
	var radius = _aura_shape.radius
	if radius <= 0.0: return
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.12, 0.04, 0.08))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, Color(1.0, 0.18, 0.06, 0.8), 4.0, true)

func _begin_ranged_transformation():
	_phase2_active = true
	_ranged_transforming = true
	_ranged_transform_elapsed = 0.0
	_ranged_transform_start_hp = _hp
	_ranged_body_rotation = _body.rotation
	_stop_heal_pluses()
	_ranged_shot_count = 0
	_ranged_transform_shields_fired = false
	_ranged_volley_left = 0
	_is_invulnerable = true
	velocity = Vector2.ZERO
	_retreating = false
	if _shot_flash:
		_shot_flash.stop()
		_shot_flash.visible = false

func _process_ranged_transformation(delta: float):
	velocity = Vector2.ZERO
	_ranged_transform_elapsed = minf(RANGED_TRANSFORM_TIME, _ranged_transform_elapsed + delta)
	if not _ranged_transform_shields_fired and is_instance_valid(_player):
		_ranged_transform_shields_fired = true
		var toward_player = (_player.global_position - global_position).normalized()
		if toward_player.is_zero_approx(): toward_player = Vector2.UP.rotated(global_rotation)
		var muzzle_distance = global_position.distance_to(_bullet_position.global_position)
		for offset in [-RANGED_TRANSFORM_SHIELD_ANGLE, 0.0, RANGED_TRANSFORM_SHIELD_ANGLE]:
			var direction = toward_player.rotated(offset)
			_spawn_ranged_shield(direction, global_position + direction * muzzle_distance)
	# Вращается изображение, физический корпус остаётся неподвижным у стен.
	_body.rotation += TAU * 1.5 * delta
	_gun.rotation = 0.0
	_hp = maxi(_hp, roundi(lerpf(_ranged_transform_start_hp, _max_hp, _ranged_transform_elapsed / RANGED_TRANSFORM_TIME)))
	_hp_bar.value = _hp
	_update_damage_visuals()
	_process_heal_pluses(delta)
	if _ranged_transform_elapsed >= RANGED_TRANSFORM_TIME:
		_hp = _max_hp
		_hp_bar.value = _hp
		_body.rotation = _ranged_body_rotation
		_ranged_transforming = false
		_is_invulnerable = false
		_fire_rate = RANGED_PHASE2_FIRE_RATE
		_shoot_timer.wait_time = _fire_rate
		_shoot_timer.start()
		_stop_heal_pluses()

func _process_heal_pluses(delta: float):
	if not is_instance_valid(_ranged_heal_effect):
		_ranged_heal_effect = Node2D.new()
		_ranged_heal_effect.top_level = true
		add_child(_ranged_heal_effect)
	_ranged_heal_effect.global_position = global_position
	_ranged_plus_time -= delta
	if _ranged_plus_time <= 0.0:
		_ranged_plus_time += 0.35
		for i in range(3):
			var plus = Sprite2D.new()
			plus.texture = HEAL_PLUS_TEXTURE
			plus.scale = Vector2(0.04, 0.04)
			plus.modulate = Color(0.2, 1.0, 0.2, 0.8)
			plus.z_index = 5
			plus.position = Vector2(randf_range(-50, 50), randf_range(-55, -15))
			_ranged_heal_effect.add_child(plus)
			var tween = plus.create_tween().set_parallel(true)
			tween.tween_property(plus, "position", plus.position + Vector2(randf_range(-30, 30), -100), 1.0).set_trans(Tween.TRANS_SINE)
			tween.tween_property(plus, "modulate:a", 0.0, 1.0)
			tween.tween_property(plus, "scale", Vector2(0.06, 0.06), 1.0)
			tween.finished.connect(plus.queue_free)

func _stop_heal_pluses():
	_ranged_plus_time = 0.0
	if is_instance_valid(_ranged_heal_effect):
		_ranged_heal_effect.queue_free()
	_ranged_heal_effect = null

func _setup_thread_line():
	_thread_line = Line2D.new()
	# Мировые координаты сохраняют толщину и размер повторов при повороте танка.
	_thread_line.top_level = true
	_thread_line.width = LINE_HIT_RADIUS * 2.0
	_thread_line.default_color = Color.WHITE
	_thread_line.texture = THREAD_TEXTURES[0]
	_thread_line.texture_mode = Line2D.LINE_TEXTURE_TILE
	_thread_line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_thread_line.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_thread_line.z_index = -1
	_thread_line.z_as_relative = false
	_thread_line.visible = false
	add_child(_thread_line)
	_thread_line.global_position = Vector2.ZERO

func take_heal(amount: float):
	_hp = min(_hp + int(amount), _max_hp)
	tank_health_changed.emit(_hp, _max_hp)
	if _hp_bar: _hp_bar.value = _hp
	_update_damage_visuals()

func _update_target():
	# Обычный ИИ не должен подменять путь отхода путём к игроку.
	if variant == TwinVariant.MELEE and _nav_return_active: return
	if variant == TwinVariant.RANGED and _retreating:
		return
	super._update_target()

func _set_retreat_destination(target_pos: Vector2):
	var map = _nav2d.get_navigation_map()
	if not map.is_valid() or NavigationServer2D.map_get_iteration_id(map) == 0:
		_nav2d.target_position = global_position
		return

	var away = (global_position - target_pos).normalized()
	if away.is_zero_approx():
		away = Vector2.UP
	var current_distance = global_position.distance_to(target_pos)
	var best_score = -INF
	var best_pos = global_position
	# Если отход прямо закрыт стеной, ищем доступную точку сбоку.
	for angle in [0.0, PI / 4, -PI / 4, PI / 2, -PI / 2]:
		var desired = global_position + away.rotated(angle) * _keep_distance
		var candidate = NavigationServer2D.map_get_closest_point(map, desired)
		var target_distance = candidate.distance_to(target_pos)
		if target_distance <= current_distance:
			continue
		var path = NavigationServer2D.map_get_path(map, global_position, candidate, true, _nav2d.navigation_layers)
		if path.size() < 2 or path[path.size() - 1].distance_to(candidate) > _nav2d.target_desired_distance:
			continue
		var path_length = 0.0
		for i in range(1, path.size()):
			path_length += path[i - 1].distance_to(path[i])
		var score = target_distance - path_length * 0.35
		if score > best_score:
			best_score = score
			best_pos = candidate
	_nav2d.target_position = best_pos

# Дальнобойный близнец отступает по навигации, если игрок слишком близко.
func _move_enemy(delta: float):
	if variant == TwinVariant.MELEE and _nav_return_active:
		_move_back_to_navigation(delta)
		return
	if variant != TwinVariant.RANGED:
		_move_melee(delta)
		return

	var target = _get_current_target()
	if is_instance_valid(target) and _target_in_sight and _nav2d != null:
		var dist = global_position.distance_to(target.global_position)
		if dist < _keep_distance:
			if not _retreating:
				_retreating = true
				_retreat_repath_timer = 0.0
			_retreat_repath_timer -= delta
			if _retreat_repath_timer <= 0.0:
				_set_retreat_destination(target.global_position)
				_retreat_repath_timer = 0.4
			var retreat_dir = Vector2.ZERO
			if not _nav2d.is_navigation_finished():
				retreat_dir = (_nav2d.get_next_path_position() - global_position).normalized()
			velocity = velocity.lerp(retreat_dir * _chase_speed, delta * 9.0)
			if velocity.length() > 15.0:
				rotation = lerp_angle(rotation, velocity.angle() + PI / 2, delta * 6.0)
			return
	if _retreating:
		_retreating = false
		super._update_target()
	super._move_enemy(delta)

func _move_melee(delta: float):
	var speed = _chase_speed if _current_state == State.CHASE else _patrol_speed
	if _nav2d == null or speed <= 0:
		velocity = velocity.move_toward(Vector2.ZERO, delta * 600.0)
		return
	var direction = Vector2.ZERO
	if not _nav2d.is_navigation_finished():
		direction = (_nav2d.get_next_path_position() - global_position).normalized()
	var frame = Engine.get_physics_frames() + _logic_frame_offset
	if frame % 8 == 0: _cached_avoidance = _compute_ally_avoidance(direction)
	if frame % 10 == 0: _cached_wall_avoidance = _compute_wall_avoidance(direction)
	_smoothed_avoidance = _smoothed_avoidance.lerp(_cached_avoidance, delta * 12.0)
	_wall_avoidance = _wall_avoidance.lerp(_cached_wall_avoidance, delta * 10.0)
	_follow_mult = lerpf(_follow_mult, _cached_follow_mult, delta * 6.0)
	_speed_limit_mult = _follow_mult
	var target = _get_current_target()
	# Узкий просвет для выстрела ещё не означает, что корпус пройдёт к игроку.
	var can_stop = is_instance_valid(target) and _target_in_sight and _roll_out_timer <= 0.0 and global_position.distance_to(target.global_position) <= _attack_range and _can_ram_reach_player()
	var steering = _smoothed_avoidance * 1.2 + _wall_avoidance * 1.5
	if can_stop:
		steering = (_smoothed_avoidance * 0.36 + _wall_avoidance * 1.5).limit_length(1.0)
		# Не усиливаем затухающее отталкивание до полной скорости.
		if steering.length_squared() < 0.0025: steering = Vector2.ZERO
	else:
		steering = (direction + steering).normalized()
	velocity = velocity.lerp(steering * speed * _speed_limit_mult, delta * 9.0)
	if velocity.length() > 15.0:
		var turn = lerp_angle(rotation, velocity.angle() + PI / 2, delta * 6.0) - rotation
		if not test_move(global_transform.rotated_local(turn), Vector2.ZERO, null, 0.08, true):
			rotation += turn

func _compute_ally_avoidance(forward: Vector2) -> Vector2:
	var force = super._compute_ally_avoidance(forward)
	# Объезд синего не должен пересиливать маршрут и разворачивать красного назад.
	return force.limit_length(0.65) if variant == TwinVariant.MELEE else force

func _compute_wall_avoidance(forward: Vector2) -> Vector2:
	if variant != TwinVariant.MELEE: return super._compute_wall_avoidance(forward)
	if forward.length_squared() < 0.01: return Vector2.ZERO
	var excluded: Array[RID] = [get_rid()]
	for group in ["enemies", "players"]:
		for body in get_tree().get_nodes_in_group(group):
			if body is PhysicsBody2D and body.get_rid() not in excluded:
				excluded.append(body.get_rid())
	var force = Vector2.ZERO
	var size = 80.0 * maxf(scale.x, scale.y)
	for angle in [0.0, -PI / 180.0 * 25.0, PI / 180.0 * 25.0]:
		var length = size * (1.5 if angle == 0.0 else 1.1)
		var query = PhysicsRayQueryParameters2D.create(global_position, global_position + forward.rotated(angle) * length, 1, excluded)
		var hit = get_world_2d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			force += hit.normal * (1.0 - global_position.distance_to(hit.position) / length)
	return force

# Егерь выпускает щиты и за пределами обычной дистанции стрельбы.
func _check_and_fire():
	if variant == TwinVariant.RANGED and _melee_twin_lost and not _ranged_transforming and _ranged_volley_left == 0 and is_instance_valid(_player) and not _target_in_sight and not _is_target_visible_at(_player):
		if _shoot_timer.time_left <= 0.0 and _station_replan_time <= 0.0:
			_station_replan_time = 0.5
			var stations = _get_owned_installations()
			if stations.size() < MINI_INSTALLATION_LIMIT:
				var placement = STATION_PLACEMENT_SCRIPT.find_target(self, _player, stations, MINI_INSTALLATION_DISTANCE)
				if not placement.is_empty() and _spawn_mini_installation(placement[0]):
					_shoot_timer.start()
		return
	if variant == TwinVariant.RANGED and _phase2_active:
		var target = _get_current_target()
		if is_instance_valid(target) and target == _player and global_position.distance_to(target.global_position) > _attack_range:
			if _target_in_sight: _fire_at_pos(target.global_position)
			return
	super._check_and_fire()

func _fire_at_pos(pos: Vector2):
	if _ranged_transforming: return
	if _is_mini_ram_mode(): return
	if _ranged_volley_left > 0: return
	if variant == TwinVariant.MELEE and _ram_state != RamState.NORMAL: return
	if _shoot_timer.time_left > 0: return
	if _gun == null or _bullet_position == null: return

	var angle = (pos - _gun.global_position).angle() + PI / 2
	if variant == TwinVariant.RANGED:
		var distant = _phase2_active and global_position.distance_to(pos) > _attack_range
		var paired_alive = is_instance_valid(twin) and not twin.is_queued_for_deletion() and twin._hp > 0 and not _melee_twin_lost
		var fourth_shot = false
		if _phase2_active or _melee_twin_lost or paired_alive:
			_ranged_shot_count += 1
			fourth_shot = _ranged_shot_count % 4 == 0
		if distant or (_phase2_active and fourth_shot):
			var spread = randf_range(-RANGED_DISTANT_SHIELD_SPREAD, RANGED_DISTANT_SHIELD_SPREAD) if distant else 0.0
			_spawn_ranged_shield(Vector2.UP.rotated(angle + spread), _bullet_position.global_position)
		elif not (fourth_shot and (_melee_twin_lost or paired_alive)):
			_spawn_twin_bullet(angle)
		if fourth_shot and paired_alive:
			var projectile = _spawn_twin_bullet(angle)
			_spawn_energy_links([[projectile, self], [projectile, twin]])
		elif fourth_shot and _melee_twin_lost:
			var last_attack = SurvivorAttack.ELECTRIC_PAIR if _get_owned_installations().size() >= MINI_INSTALLATION_LIMIT else SurvivorAttack.MINI_INSTALLATION
			_fire_survivor_attack(randi_range(SurvivorAttack.CLUSTER, last_attack), pos)
	else:
		_spawn_twin_bullet(angle)
	_shoot_timer.start()

func _spawn_ranged_shield(direction: Vector2, origin: Vector2):
	var shield = SHIELD_SCRIPT.new()
	var parent = get_parent() as Node2D
	shield.direction = direction
	shield.travel_distance = maxf(0.0, RANGED_SHIELD_DISTANCE - (origin - global_position).dot(direction))
	shield.position = parent.to_local(origin)
	parent.add_child(shield)
	if _shot_flash:
		_shot_flash.visible = true
		_shot_flash.play("Fire")

func _fire_survivor_attack(attack: SurvivorAttack, target_pos: Vector2):
	var angle = (target_pos - _bullet_position.global_position).angle() + PI / 2
	match attack:
		SurvivorAttack.CLUSTER:
			_spawn_twin_bullet(angle, _spread, SPECIAL_BULLET_SCRIPT.Kind.CLUSTER)
		SurvivorAttack.FIRE:
			for offset in [-SURVIVOR_FIRE_ANGLE, SURVIVOR_FIRE_ANGLE]:
				_spawn_twin_bullet(angle + offset, 0.0, SPECIAL_BULLET_SCRIPT.Kind.FIRE)
		SurvivorAttack.VOLLEY:
			var velocity = _player.velocity if is_instance_valid(_player) else Vector2.ZERO
			var intercept = _get_intercept_position(_bullet_position.global_position, target_pos, velocity)
			_spawn_twin_bullet((intercept - _bullet_position.global_position).angle() + PI / 2, 0.0)
			_ranged_volley_left = 2
			_ranged_volley_interval = _fire_rate * 0.5
			_ranged_volley_time = _ranged_volley_interval
		SurvivorAttack.ELECTRIC_PAIR:
			var projectiles: Array = []
			for offset in [-SURVIVOR_FIRE_ANGLE, SURVIVOR_FIRE_ANGLE]:
				projectiles.append(_spawn_twin_bullet(angle + offset, 0.0, SPECIAL_BULLET_SCRIPT.Kind.ELECTRIC_PAIR))
			_spawn_energy_links([[projectiles[0], projectiles[1]]])
		SurvivorAttack.MINI_INSTALLATION:
			angle = (target_pos - global_position).angle() + PI / 2 + randf_range(-MINI_INSTALLATION_SPREAD, MINI_INSTALLATION_SPREAD)
			_spawn_mini_installation(global_position + Vector2.UP.rotated(angle) * MINI_INSTALLATION_DISTANCE)

func _get_owned_installations() -> Array:
	return get_tree().get_nodes_in_group("enemy_installations").filter(func(station): return not station.is_queued_for_deletion() and station.emitter == self)

func _spawn_mini_installation(target: Vector2) -> bool:
	if _get_owned_installations().size() >= MINI_INSTALLATION_LIMIT: return false
	var installation = MINI_INSTALLATION_SCENE.instantiate()
	var field = get_parent() as Node2D
	_gun.global_rotation = (target - _gun.global_position).angle() + PI / 2
	installation.emitter = self
	installation.position = field.to_local(_bullet_position.global_position)
	installation.target_position = target
	field.add_child(installation)
	_spawn_energy_links([[self, installation]])
	if _shot_flash:
		_shot_flash.visible = true
		_shot_flash.play("Fire")
	return true

func _spawn_energy_links(connections: Array):
	var links = ENERGY_LINKS_SCRIPT.new()
	links.connections = connections
	links.frames = THREAD_TEXTURES
	links.damage = LINE_DAMAGE
	links.hit_interval = LINE_DAMAGE_COOLDOWN
	links.hit_radius = LINE_HIT_RADIUS
	links.animation_fps = THREAD_ANIMATION_FPS
	links.bend_amplitude = THREAD_BEND_AMPLITUDE
	links.segment_length = THREAD_SEGMENT_LENGTH
	get_parent().add_child(links)

func _get_intercept_position(origin: Vector2, target: Vector2, target_velocity: Vector2) -> Vector2:
	var relative = target - origin
	var a = target_velocity.length_squared() - RANGED_PROJECTILE_SPEED * RANGED_PROJECTILE_SPEED
	var b = 2.0 * relative.dot(target_velocity)
	var c = relative.length_squared()
	var time = -1.0
	if absf(a) < 0.001:
		if absf(b) > 0.001: time = -c / b
	else:
		var discriminant = b * b - 4.0 * a * c
		if discriminant >= 0.0:
			var root = sqrt(discriminant)
			for candidate in [(-b - root) / (2.0 * a), (-b + root) / (2.0 * a)]:
				if candidate > 0.0 and (time < 0.0 or candidate < time): time = candidate
	return target + target_velocity * time if time > 0.0 else target

func _process_ranged_volley(delta: float):
	if _ranged_volley_left <= 0: return
	if not is_instance_valid(_player) or _player.is_queued_for_deletion():
		_ranged_volley_left = 0
		return
	_ranged_volley_time -= delta
	if _ranged_volley_time > 0.00001: return
	var angle = (_player.global_position - _bullet_position.global_position).angle() + PI / 2
	_spawn_twin_bullet(angle, VOLLEY_SPREAD)
	_ranged_volley_left -= 1
	_ranged_volley_time += _ranged_volley_interval
	if _ranged_volley_left == 0: _shoot_timer.start(_fire_rate)

func _spawn_twin_bullet(angle: float, spread_override: float = -1.0, special_kind: int = -1) -> Node2D:
	if _mini_ram_active or _is_mini_ram_mode(): return null
	if variant == TwinVariant.MELEE:
		var muzzle = _gun.get_node("Barrels/LeftMuzzle" if _fire_left_barrel else "Barrels/RightMuzzle") as Marker2D
		_bullet_position.global_position = muzzle.global_position

	if AudioManager: AudioManager.play_bullet_sound(0, global_position)
	var b = _bullet_scene.instantiate()
	if special_kind >= 0:
		b.set_script(SPECIAL_BULLET_SCRIPT)
		b.kind = special_kind
		if special_kind == SPECIAL_BULLET_SCRIPT.Kind.FIRE:
			if not is_instance_valid(_ranged_fire_trail):
				_ranged_fire_trail = FIRE_TRAIL_SCRIPT.new()
				get_parent().add_child(_ranged_fire_trail)
			b.fire_trail = _ranged_fire_trail
	var bullet_parent = get_parent() as Node2D
	b.position = bullet_parent.to_local(_bullet_position.global_position)
	var spread = _spread if spread_override < 0.0 else spread_override
	b.rotation = angle + randf_range(-spread, spread) - bullet_parent.global_rotation
	bullet_parent.add_child(b)
	if variant == TwinVariant.MELEE:
		b.init(0, false, _damage, get_rid(), MELEE_BULLET_RANGE)
		_fire_left_barrel = not _fire_left_barrel
	else:
		b.init(2, false, _damage, get_rid()) # 2 = лёгкий снаряд (дальность 1000)
	if _shot_flash:
		_shot_flash.visible = true
		_shot_flash.play("Fire")
	return b

func _physics_process(delta):
	_station_replan_time = maxf(0.0, _station_replan_time - delta)
	_update_phase2()
	if variant == TwinVariant.RANGED and _ranged_transforming:
		_process_ranged_transformation(delta)
		_handle_movement_sound(Vector2.ZERO)
		_update_thread(delta)
		return
	if variant == TwinVariant.RANGED: _process_ranged_volley(delta)
	if variant == TwinVariant.MELEE:
		_update_mini_ram_mode()
		if _ram_state == RamState.NORMAL:
			_ram_cooldown = maxf(0.0, _ram_cooldown - delta)
			_update_navigation_return(delta)
			if not _nav_return_active: _try_prepare_ram()
		if _ram_state != RamState.NORMAL:
			_process_ram(delta)
			_handle_movement_sound(velocity)
			_update_thread(delta)
			_process_phase2_aura(delta)
			return
	super._physics_process(delta)
	if variant == TwinVariant.RANGED: _process_hidden_healing(delta)
	_update_thread(delta)
	_process_phase2_aura(delta)

func _process_hidden_healing(delta: float):
	if not _phase2_active or not _melee_twin_lost or not is_instance_valid(_player) or _is_target_visible_at(_player):
		_ranged_unseen_time = 0.0
		_ranged_hidden_heal_accum = 0.0
		_stop_heal_pluses()
		return
	var previous = _ranged_unseen_time
	_ranged_unseen_time += delta
	# В зачёт лечения идёт только время после пяти секунд без видимости.
	_ranged_hidden_heal_accum += maxf(0.0, _ranged_unseen_time - RANGED_HIDDEN_HEAL_DELAY) - maxf(0.0, previous - RANGED_HIDDEN_HEAL_DELAY)
	while _ranged_hidden_heal_accum >= 1.0:
		_ranged_hidden_heal_accum -= 1.0
		take_heal(HEAL_RATE)
	if _ranged_unseen_time >= RANGED_HIDDEN_HEAL_DELAY and _hp < _max_hp:
		_process_heal_pluses(delta)
	else:
		_stop_heal_pluses()

func _update_navigation_return(delta: float):
	if _nav2d == null: return
	var map = _nav2d.get_navigation_map()
	if not map.is_valid() or NavigationServer2D.map_get_iteration_id(map) == 0:
		_nav_return_active = false
		_nav_return_path.clear()
		return
	if not NavigationServer2D.map_get_closest_point_owner(map, global_position).is_valid():
		_nav_return_active = false
		_nav_return_path.clear()
		return
	var nearest = NavigationServer2D.map_get_closest_point(map, global_position)
	if global_position.distance_to(nearest) <= NAV_RETURN_TOLERANCE:
		if _nav_return_active:
			_nav_return_active = false
			_nav_return_path.clear()
			_nav_return_stuck_time = 0.0
			velocity = Vector2.ZERO
			super._update_target()
		return
	var iteration = NavigationServer2D.map_get_iteration_id(map)
	_nav_return_retry = maxf(0.0, _nav_return_retry - delta)
	if not _nav_return_active or iteration != _nav_return_map_iteration or _nav_return_stuck_time >= NAV_RETURN_RETRY or (_nav_return_path.is_empty() and _nav_return_retry <= 0.0):
		_nav_return_active = true
		_nav_return_path = NAV_RETURN_SCRIPT.find_path(self, map)
		_nav_return_waypoint = 1
		_nav_return_retry = NAV_RETURN_RETRY
		_nav_return_stuck_time = 0.0
		_nav_return_map_iteration = iteration
		_nav_return_last_position = global_position
		if not _nav_return_path.is_empty(): _nav2d.target_position = _nav_return_path[-1]

func _move_back_to_navigation(delta: float):
	if global_position.distance_to(_nav_return_last_position) < 0.2:
		_nav_return_stuck_time += delta
	else:
		_nav_return_stuck_time = 0.0
	_nav_return_last_position = global_position
	while _nav_return_waypoint < _nav_return_path.size() and global_position.distance_to(_nav_return_path[_nav_return_waypoint]) <= NAV_RETURN_TOLERANCE:
		_nav_return_waypoint += 1
	if _nav_return_waypoint >= _nav_return_path.size():
		velocity = velocity.move_toward(Vector2.ZERO, delta * 900.0)
		return
	var offset = _nav_return_path[_nav_return_waypoint] - global_position
	var direction = offset.normalized()
	velocity = direction * minf(_chase_speed, offset.length() / maxf(delta, 0.001))
	var turn = lerp_angle(global_rotation, direction.angle() + PI / 2, minf(1.0, delta * 8.0)) - global_rotation
	if not test_move(global_transform.rotated_local(turn), Vector2.ZERO, null, 0.08, true):
		global_rotation += turn

func _is_mini_ram_mode() -> bool:
	return variant == TwinVariant.MELEE and _ranged_twin_lost and _hp <= _max_hp * MINI_RAM_HP_RATIO

func _update_mini_ram_mode():
	var active = _is_mini_ram_mode()
	var changed = active != _mini_ram_mode_active
	if active and not _mini_ram_mode_active:
		if _ram_state == RamState.NORMAL:
			if _has_rammed_once:
				_ram_cooldown = maxf(0.0, _ram_cooldown - (PHASE2_RAM_COOLDOWN - MINI_RAM_COOLDOWN))
			else:
				_ram_cooldown = minf(_ram_cooldown, MINI_RAM_COOLDOWN)
		if _shot_flash:
			_shot_flash.stop()
			_shot_flash.visible = false
	_mini_ram_mode_active = active
	if _gun:
		_gun.visible = true
		var barrels = _gun.get_node_or_null("Barrels") as Sprite2D
		if barrels and (active or changed): barrels.visible = not active

func _try_prepare_ram():
	if _ram_cooldown > 0.0 or not is_instance_valid(_player): return
	var distance = global_position.distance_to(_player.global_position)
	if _is_mini_ram_mode():
		if distance <= 0.01 or distance > MINI_RAM_APPROACH_DISTANCE: return
		if not _is_line_clear_to_target(global_position, _player): return
		if distance > RAM_MAX_START_DISTANCE:
			var direction = (_player.global_position - global_position).normalized()
			if _get_ram_warning_distance(direction, MINI_RAM_DISTANCE) < RAM_APPROACH_MIN_TRAVEL: return
		_begin_ram_preparation(false)
		return
	if distance < RAM_MIN_DISTANCE: return
	var approaching = distance > RAM_MAX_START_DISTANCE
	if approaching and distance > RAM_APPROACH_MAX_DISTANCE: return
	if not _is_line_clear_to_target(global_position, _player): return
	if not _can_ram_reach_player(): return
	if approaching:
		var direction = (_player.global_position - global_position).normalized()
		if _get_ram_warning_distance(direction, RAM_DISTANCE) < RAM_APPROACH_MIN_TRAVEL: return
	_begin_ram_preparation(false)

func _can_ram_reach_player() -> bool:
	if not is_instance_valid(_player): return false
	var offset = _player.global_position - global_position
	if offset.is_zero_approx(): return true
	var direction = offset.normalized()
	var body_shape = get_node("CollisionShape2D") as CollisionShape2D
	var player_shape = _player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var body_reach = body_shape.shape.get_rect().size.y * 0.5 * maxf(absf(global_scale.x), absf(global_scale.y))
	var player_reach = 0.0
	if player_shape and player_shape.shape:
		var shape = player_shape.shape
		var sx = player_shape.global_transform.x.length()
		var sy = player_shape.global_transform.y.length()
		if shape is CapsuleShape2D:
			player_reach = shape.radius * maxf(sx, sy) + maxf(0.0, shape.height * 0.5 - shape.radius) * sy * absf(direction.dot(player_shape.global_transform.y.normalized()))
		else:
			var half = shape.get_rect().size * 0.5
			player_reach = half.x * sx * absf(direction.dot(player_shape.global_transform.x.normalized())) + half.y * sy * absf(direction.dot(player_shape.global_transform.y.normalized()))
	var required = minf(RAM_DISTANCE, maxf(0.0, offset.length() - body_reach - player_reach + 1.0))
	return required <= 0.01 or _get_ram_warning_distance(direction, required) >= required - 0.5

func _begin_ram_preparation(second_dash: bool):
	if not second_dash:
		_mini_ram_active = _is_mini_ram_mode()
		_mini_ram_dash_index = 1 if _mini_ram_active else 0
	_ram_second_dash = second_dash
	_ram_charge_distance = MINI_RAM_DISTANCE if _mini_ram_active else (RAM_SECOND_DISTANCE if second_dash else RAM_DISTANCE)
	_ram_shots_fired = 0
	_ram_shot_time = 0.0
	_ram_direction = (_player.global_position - global_position).normalized()
	_ram_warning_distance = _get_ram_warning_distance(_ram_direction, _ram_charge_distance)
	_ram_state = RamState.PREPARING
	_ram_prepare_duration = MINI_RAM_PREPARE_TIME if _mini_ram_active else (RAM_SECOND_PREPARE_TIME if second_dash else RAM_PREPARE_TIME)
	_ram_time = _ram_prepare_duration
	velocity = Vector2.ZERO
	_ram_warning_base_modulate = _body.modulate
	_update_ram_warning()

func _start_ram_charge():
	_clear_ram_warning()
	_ram_state = RamState.CHARGING
	_has_rammed_once = true
	_ram_remaining = _ram_charge_distance
	_ram_speed = RAM_SPEED
	rotation = _ram_direction.angle() + PI / 2
	_gun.global_rotation = _ram_direction.angle() - PI / 2
	_body.self_modulate = _base_tint

func _begin_next_mini_ram():
	_ram_direction = (_player.global_position - global_position).normalized()
	if _ram_direction.is_zero_approx():
		_begin_ram_recovery()
		return
	_mini_ram_dash_index += 1
	_ram_shots_fired = 0
	_ram_shot_time = 0.0
	_ram_warning_distance = _get_ram_warning_distance(_ram_direction, _ram_charge_distance)
	_ram_state = RamState.PREPARING
	_ram_prepare_duration = MINI_RAM_INTERVAL
	_ram_time = MINI_RAM_INTERVAL
	velocity = Vector2.ZERO
	_ram_warning_base_modulate = _body.modulate
	_update_ram_warning()

func _start_next_mini_ram_charge():
	# Мгновенный разворот не должен повернуть длинный корпус внутрь стены или игрока.
	var turn = _ram_direction.angle() + PI / 2 - rotation
	var next_transform = global_transform.rotated_local(turn)
	var collision = KinematicCollision2D.new()
	for attempt in range(16):
		if not test_move(next_transform, Vector2.ZERO, collision, 0.08, true):
			_start_ram_charge()
			return
		var collider = collision.get_collider()
		if collider is Node and collider.has_method("destroyable") and collider.destroyable():
			if collider is PhysicsBody2D: add_collision_exception_with(collider)
			collider.destroy()
			continue
		if collider is Player:
			collider.receive_ram_hit(_ram_direction, RAM_DAMAGE)
			_begin_ram_stun(RAM_PLAYER_STUN)
		elif collider is StaticBody2D or collider is TileMapLayer or collider is TileMap:
			_begin_ram_recovery()
		else:
			_begin_ram_recovery()
		return
	_begin_ram_recovery()

func _setup_ram_warning():
	if variant != TwinVariant.MELEE: return
	_ram_warning = Line2D.new()
	_ram_warning.name = "RamWarning"
	_ram_warning.top_level = true
	_ram_warning.z_index = -1
	_ram_warning.z_as_relative = false
	_ram_warning.default_color = Color(1.0, 0.06, 0.04, 0.3)
	_ram_warning.antialiased = true
	_ram_warning.visible = false
	add_child(_ram_warning)
	_ram_warning.global_transform = Transform2D.IDENTITY
	_ram_warning_cast = ShapeCast2D.new()
	_ram_warning_cast.name = "RamWarningCast"
	_ram_warning_cast.enabled = false
	_ram_warning_cast.visible = false
	_ram_warning_cast.top_level = true
	_ram_warning_cast.shape = get_node("CollisionShape2D").shape
	_ram_warning_cast.collision_mask = collision_mask
	_ram_warning_cast.collide_with_areas = false
	_ram_warning_cast.max_results = 64
	_ram_warning_cast.margin = 0.08
	add_child(_ram_warning_cast)

func _get_ram_warning_distance(direction: Vector2, distance: float) -> float:
	var body_shape = get_node("CollisionShape2D") as CollisionShape2D
	# Проверяем корпус в том положении, в котором он поедет после подготовки.
	var turn = direction.angle() + PI / 2 - rotation
	_ram_warning_cast.global_transform = global_transform.rotated_local(turn) * body_shape.transform
	_ram_warning_cast.target_position = _ram_warning_cast.to_local(_ram_warning_cast.global_position + direction * distance)
	_ram_warning_cast.clear_exceptions()
	_ram_warning_cast.add_exception(self)
	for attempt in range(64):
		_ram_warning_cast.force_shapecast_update()
		if not _ram_warning_cast.is_colliding(): return distance
		var skipped = false
		for i in range(_ram_warning_cast.get_collision_count()):
			var collider = _ram_warning_cast.get_collider(i)
			if collider is CharacterBody2D or (collider is Node and collider.has_method("destroyable") and collider.destroyable()):
				_ram_warning_cast.add_exception_rid(_ram_warning_cast.get_collider_rid(i))
				skipped = true
		if not skipped:
			var safe_distance = distance * _ram_warning_cast.get_closest_collision_safe_fraction()
			var unsafe_distance = minf(distance, distance * _ram_warning_cast.get_closest_collision_unsafe_fraction() + 0.2)
			# Короткая повторная проверка уточняет конец длинного рывка до долей пикселя.
			var refinement = maxf(0.0, unsafe_distance - safe_distance)
			_ram_warning_cast.global_position += direction * safe_distance
			_ram_warning_cast.target_position = _ram_warning_cast.to_local(_ram_warning_cast.global_position + direction * refinement)
			_ram_warning_cast.force_shapecast_update()
			if _ram_warning_cast.is_colliding():
				return safe_distance + refinement * _ram_warning_cast.get_closest_collision_safe_fraction()
			return safe_distance
	return 0.0

func _update_ram_warning():
	var blink_on = floori((_ram_prepare_duration - _ram_time) * RAM_WARNING_BLINK_HZ * 2.0) % 2 == 0
	var mini_interval = _mini_ram_active and _mini_ram_dash_index > 1
	_body.modulate = _ram_warning_base_modulate * (Color(2.5, 2.5, 2.5, 1.0) if blink_on and not mini_interval else Color.WHITE)
	# Мировые координаты сохраняют точное направление при повороте корпуса.
	_ram_warning.width = 100.0 * maxf(absf(global_scale.x), absf(global_scale.y))
	_ram_warning.points = PackedVector2Array([global_position, global_position + _ram_direction * _ram_warning_distance])
	_ram_warning.visible = true

func _clear_ram_warning():
	if is_instance_valid(_ram_warning):
		_ram_warning.visible = false
		_body.modulate = _ram_warning_base_modulate

func _process_ram(delta: float):
	match _ram_state:
		RamState.PREPARING:
			if not is_instance_valid(_player):
				_finish_ram()
				return
			var mini_interval = _mini_ram_active and _mini_ram_dash_index > 1
			# Направление выбрано при появлении полосы; между короткими таранами корпус стоит.
			if not mini_interval:
				rotation = lerp_angle(rotation, _ram_direction.angle() + PI / 2, minf(1.0, delta * 10.0))
				_gun.global_rotation = lerp_angle(_gun.global_rotation, _ram_direction.angle() - PI / 2, minf(1.0, delta * 10.0))
			_update_ram_warning()
			_ram_time -= delta
			if _ram_time <= 0.0:
				if mini_interval:
					_start_next_mini_ram_charge()
				else:
					_start_ram_charge()
		RamState.CHARGING:
			_process_ram_charge(delta)
		RamState.STUNNED:
			_process_ram_stun(delta)
		RamState.RECOVERING:
			_ram_time -= delta
			if _ram_time <= 0.0: _finish_ram()

func _process_ram_charge(delta: float):
	velocity = _ram_direction * _ram_speed
	var motion = _ram_direction * minf(_ram_remaining, _ram_speed * delta)
	# Проверяем весь путь корпуса, включая несколько соседних блоков стены.
	for i in range(16):
		if motion.is_zero_approx(): break
		var before = global_position
		var collision = move_and_collide(motion, false, 0.08, true)
		_ram_remaining = maxf(0.0, _ram_remaining - before.distance_to(global_position))
		if collision == null: break
		var collider = collision.get_collider()
		if collider is Node and collider.has_method("destroyable") and collider.destroyable():
			# queue_free удаляет стену в конце кадра; исключение позволяет пройти пролом сейчас.
			if collider is PhysicsBody2D: add_collision_exception_with(collider)
			collider.destroy()
			_ram_speed = maxf(RAM_SPEED * 0.6, _ram_speed * 0.9)
			motion = collision.get_remainder()
			continue
		if collider is Player:
			# Освобождаем небольшой зазор физическим движением, без телепортации сквозь стены.
			move_and_collide(-_ram_direction * 18.0)
			collider.receive_ram_hit(_ram_direction, RAM_DAMAGE)
			_begin_ram_stun(RAM_PLAYER_STUN)
		elif collider is StaticBody2D or collider is TileMapLayer or collider is TileMap:
			if _mini_ram_active or _is_mini_ram_mode():
				_begin_ram_recovery()
			else:
				_begin_ram_stun(RAM_WALL_STUN)
		else:
			_begin_ram_recovery()
		return
	# Столкновение выше завершает обработку раньше очередного выстрела.
	if not _mini_ram_active and not _is_mini_ram_mode():
		_ram_shot_time -= delta
		while _ram_shot_time <= 0.0 and _ram_shots_fired < RAM_SHOTS:
			_spawn_twin_bullet(_ram_direction.angle() - PI / 2)
			_ram_shots_fired += 1
			_ram_shot_time += RAM_SHOT_INTERVAL
	if _ram_remaining <= 0.01:
		if _mini_ram_active:
			if _mini_ram_dash_index < MINI_RAM_COUNT and is_instance_valid(_player):
				_begin_next_mini_ram()
			else:
				_begin_ram_recovery()
		elif _is_mini_ram_mode():
			_begin_ram_recovery()
		elif _ranged_twin_lost and not _ram_second_dash and is_instance_valid(_player):
			_begin_ram_preparation(true)
		else:
			_begin_ram_recovery()

func _begin_ram_recovery():
	if _mini_ram_active or _is_mini_ram_mode():
		_finish_ram()
		return
	_clear_ram_warning()
	_ram_state = RamState.RECOVERING
	_ram_time = 0.5
	velocity = Vector2.ZERO

func _begin_ram_stun(duration: float):
	_clear_ram_warning()
	if _phase2_active: duration = PHASE2_RAM_STUN
	_ram_state = RamState.STUNNED
	_ram_time = duration
	_ram_stun_duration = duration
	velocity = Vector2.ZERO
	_body.self_modulate = _base_tint
	if _shot_flash:
		_shot_flash.stop()
		_shot_flash.visible = false

func _process_ram_stun(delta: float):
	_ram_time = maxf(0.0, _ram_time - delta)
	var barrels = _gun.get_node("Barrels") as Sprite2D
	var elapsed = _ram_stun_duration - _ram_time
	if elapsed < RAM_BARREL_ANIMATION_TIME:
		barrels.position.y = RAM_BARREL_RETRACT * elapsed / RAM_BARREL_ANIMATION_TIME
	elif _ram_time > RAM_BARREL_ANIMATION_TIME:
		barrels.visible = false
		_gun.rotation += TAU * 1.5 * delta
	else:
		barrels.visible = true
		barrels.position.y = RAM_BARREL_RETRACT * _ram_time / RAM_BARREL_ANIMATION_TIME
	if _is_mini_ram_mode(): barrels.visible = false
	if _ram_time <= 0.0: _finish_ram()

func _finish_ram():
	_clear_ram_warning()
	var mini_mode = _mini_ram_active or _is_mini_ram_mode()
	_mini_ram_active = false
	_mini_ram_dash_index = 0
	_ram_state = RamState.NORMAL
	_ram_cooldown = MINI_RAM_COOLDOWN if mini_mode else (PHASE2_RAM_COOLDOWN if _phase2_active else RAM_COOLDOWN)
	velocity = Vector2.ZERO
	_body.self_modulate = _base_tint
	var barrels = _gun.get_node("Barrels") as Sprite2D
	barrels.position = Vector2.ZERO
	barrels.visible = not _is_mini_ram_mode()

func _update_thread(delta):
	if not is_instance_valid(twin):
		if _thread_line: _thread_line.visible = false
		return

	# Рисуем одну связь на пару, чтобы две текстуры не накладывались друг на друга.
	_thread_line.visible = get_instance_id() < twin.get_instance_id()
	if _thread_line.visible:
		_thread_bend_time += delta
		var step = floori(_thread_bend_time * THREAD_ANIMATION_FPS)
		var separation = twin.global_position - global_position
		var perpendicular = separation.normalized().orthogonal()
		var segments = maxi(1, ceili(separation.length() / THREAD_SEGMENT_LENGTH))
		_thread_line.clear_points()
		for i in range(segments + 1):
			var t = float(i) / segments
			var point = global_position.lerp(twin.global_position, t)
			if i > 0 and i < segments:
				var sample = float(step) + i * 17.17
				var bend = sin(sample * 1.73) * 0.7 + sin(sample * 0.93 + i * 2.1) * 0.3
				point += perpendicular * bend * THREAD_BEND_AMPLITUDE * sin(PI * t)
			_thread_line.add_point(point)
		_thread_animation_time = fmod(_thread_animation_time + delta, THREAD_TEXTURES.size() / THREAD_ANIMATION_FPS)
		var frame = mini(int(_thread_animation_time * THREAD_ANIMATION_FPS), THREAD_TEXTURES.size() - 1)
		if frame != _thread_frame:
			_thread_frame = frame
			_thread_line.texture = THREAD_TEXTURES[frame]

	_heal_accum += delta
	if _heal_accum >= 1.0:
		_heal_accum -= 1.0
		twin.take_heal(HEAL_RATE)

	# Урон по игроку считает только один близнец (по меньшему id), чтобы не удвоить.
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

func _destroy():
	_clear_ram_warning()
	if is_instance_valid(twin):
		twin.twin = null
	super._destroy()
