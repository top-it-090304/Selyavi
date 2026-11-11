extends Enemy
class_name TwinBoss

enum TwinVariant { MELEE, RANGED }

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

func _enter_tree():
	add_to_group("twin_bosses")

func _ready():
	_type_enemy = TypeEnemy.BOSS
	super._ready()
	_apply_variant_stats()
	_setup_thread_line()
	_apply_variant_tint()
	_setup_hp_bar()
	_resolve_twin_path()
	_auto_pair_with_sibling()

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
			_max_hp = 420; _hp = _max_hp
			_damage = 24
			_fire_rate = 0.55
			_spread = 0.18
			_patrol_speed = 150
			_chase_speed = 170
			_notice_range = 950.0
			_attack_range = 240.0
		TwinVariant.RANGED:
			# Егерь: хрупче и медленнее, но бьёт больно, точно и издалека.
			_max_hp = 300; _hp = _max_hp
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
		# Красная (Color_D) текстура — уже используется по умолчанию, дополнительно
		# насыщаем её через self_modulate, чтобы турель и корпус были одинаково красными.
		_base_tint = Color(1.4, 0.55, 0.5)
	else:
		# Меняем саму текстуру на лазурную линейку (Color_C) — просто тонировать
		# красную текстуру в синий не выйдет (умножение не добавляет недостающий канал).
		_body.texture = load("res://assets/future_tanks/PNG/Hulls_Color_C/Hull_01.png")
		if _gun: _gun.texture = load("res://assets/future_tanks/PNG/Weapon_Color_C/Gun_03.png")
		_base_tint = Color(0.6, 0.9, 1.3)

	_body.self_modulate = _base_tint
	if _gun: _gun.self_modulate = _base_tint

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

func _setup_hp_bar():
	var canvas = CanvasLayer.new()
	add_child(canvas)

	var bar_color = Color(0.85, 0.3, 0.25) if variant == TwinVariant.MELEE else Color(0.3, 0.55, 0.9)
	var boss_name = "ШТУРМОВИК" if variant == TwinVariant.MELEE else "ЕГЕРЬ"
	# Разносим полосы двух близнецов по вертикали, чтобы не накладывались друг на
	# друга — оба видны на экране одновременно (в отличие от одиночных боссов).
	var row_offset = 0.0 if variant == TwinVariant.MELEE else 50.0

	_hp_bar = ProgressBar.new()
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
	_hp_bar_label.text = "БЛИЗНЕЦ: " + boss_name
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

func _update_target():
	# Обычный ИИ не должен подменять путь отхода путём к игроку.
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
	if variant != TwinVariant.RANGED:
		super._move_enemy(delta)
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

# Дальнобойный стреляет лёгким снарядом с большой дальностью полёта.
func _fire_at_pos(pos: Vector2):
	if variant != TwinVariant.RANGED:
		super._fire_at_pos(pos)
		return
	if _shoot_timer.time_left > 0: return
	if _gun == null or _bullet_position == null: return

	var a = (pos - _gun.global_position).angle() + PI / 2
	if AudioManager: AudioManager.play_bullet_sound(0, global_position)
	var b = _bullet_scene.instantiate()
	b.global_position = _bullet_position.global_position
	b.global_rotation = a + randf_range(-_spread, _spread)
	get_parent().add_child(b)
	b.init(2, false, _damage, get_rid()) # 2 = лёгкий снаряд (дальность 1000)
	if _shot_flash: _shot_flash.play("Fire")
	_shoot_timer.start()

func _physics_process(delta):
	super._physics_process(delta)
	_update_thread(delta)

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
	if is_instance_valid(twin):
		twin.twin = null
	super._destroy()
