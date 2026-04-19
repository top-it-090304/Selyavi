extends Area2D

var _bullet_speed: int = 7
var _velocity: Vector2 = Vector2.ZERO
var _bullet_sound: AudioStreamPlayer
var _visibility_bullet: VisibleOnScreenNotifier2D
var _type_bullet: int
var _bullet_sprite: Sprite2D
var _damage: int = 0
var _is_player: bool = false
var _traveled_distance: float = 0.0
var _max_range: float = 1000.0
var _ignored_body_rid: RID # RID тела, которое пуля игнорирует (например, стрелявшая база)
var _pierce_left: int = 0
var _aoe_radius: float = 0.0
var _aoe_damage_multiplier: float = 0.0
var _hit_targets: Array = [] # Список уже пораженных целей для пробития

const PLASMA: int = 0
const MEDIUM: int = 1
const LIGHT: int = 2
const HE: int = 3
const BOPS: int = 4

func _ready():
	_bullet_sprite = $BulletSprite
	_bullet_sound = $PlasmaGunSound
	_velocity = Vector2(0, -1).rotated(rotation)
	_visibility_bullet = $VisibleOnScreenNotifier2D
	
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_visibility_bullet.screen_exited.connect(_on_screen_exited)

func is_player() -> bool:
	return _is_player

func get_damage() -> int:
	return _damage

func _process(delta):
	var move_step = _velocity * _bullet_speed
	position += move_step
	_traveled_distance += move_step.length()
	# Если пролетели всю дистанцию, просто удаляем пулю без взрыва
	if _traveled_distance >= _max_range: _destroy()

func _on_area_entered(_area):
	pass

func _on_body_entered(body):
	if body in _hit_targets: return # Не бьем одну и ту же цель дважды
	if _ignored_body_rid.is_valid() and body.get_rid() == _ignored_body_rid: return

	# Проверка на физическое тело базы
	var parent = body.get_parent()
	if parent is Base or body.is_in_group("bases"):
		var base_node = parent if parent is Base else body
		_handle_base_hit(base_node)
		return

	if body is Player:
		if not _is_player:
			_hit_targets.append(body)
			body.take_damage(_damage)
			_explode(body)
		return

	if body is Enemy:
		if _is_player:
			_hit_targets.append(body)
			body.take_damage(_damage)
			# ЛОГИКА ПРОБИТИЯ (BOPS)
			if _type_bullet == BOPS and _pierce_left > 0:
				_pierce_left -= 1
			else:
				_explode(body)
		return

	if body.has_method("can_bullet_pass"):
		if body.can_bullet_pass():
			return
		elif body.has_method("destroyable") and body.destroyable():
			body.destroy()
			_explode(body)
		else:
			_explode(body)
	elif body is StaticBody2D:
		_explode(body)

func _handle_base_hit(base_node: Node):
	if base_node in _hit_targets: return

	var is_enemy_base = base_node.get("type_base") == 1

	if (_is_player and is_enemy_base) or (not _is_player and not is_enemy_base):
		_hit_targets.append(base_node)
		if base_node.has_method("take_damage"):
			base_node.take_damage(_damage)

		# БОПС должен прошивать и базу тоже
		if _type_bullet == BOPS and _pierce_left > 0:
			_pierce_left -= 1
		else:
			_explode(base_node)
	else:
		_explode(base_node)

# Логика взрыва: вызывается только при попадании
func _explode(exclude_body: Node = null):
	if _type_bullet == HE:
		_play_shockwave_effect()
		if _aoe_radius > 0.0:
			_apply_aoe_damage(exclude_body)

	_destroy()

func _play_shockwave_effect():
	var effect_scene = load("res://scripts/ExplosionEffect.gd")
	if not effect_scene: return

	var effect = Node2D.new()
	effect.set_script(effect_scene)
	get_parent().add_child(effect)
	effect.global_position = global_position
	if effect.has_method("init"):
		effect.init(_aoe_radius, Color(1, 0.6, 0.2, 0.8))

# Базовое удаление пули
func _destroy():
	queue_free()

func init(type_bullet: int, is_player: bool, damage: int = 0, ignored_rid: RID = RID(), custom_range: float = -1.0):
	_type_bullet = type_bullet
	_is_player = is_player
	_damage = damage
	_ignored_body_rid = ignored_rid
	_update_visuals_and_speed()
	if custom_range > 0: _max_range = custom_range

func _update_visuals_and_speed():
	match _type_bullet:
		PLASMA:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Plasma.png")
			_bullet_speed = 9; _max_range = 650.0
		MEDIUM:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Medium_Shell.png")
			_bullet_speed = 4; _max_range = 300.0
		LIGHT:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Light_Shell.png")
			_bullet_speed = 7; _max_range = 1000.0
		HE:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Granade_Shell.png")
			_bullet_speed = 5; _max_range = 550.0
			_aoe_radius = 105.0
			_aoe_damage_multiplier = 0.65
		BOPS:
			_bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Heavy_Shell.png")
			_bullet_speed = 8; _max_range = 1100.0
			_pierce_left = 1

func _apply_aoe_damage(hit_body: Node):
	var space_state = get_world_2d().direct_space_state
	var shape = CircleShape2D.new()
	shape.radius = _aoe_radius
	var query = PhysicsShapeQueryParameters2D.new()
	query.set_shape(shape)
	query.transform = Transform2D(0.0, global_position)
	query.exclude = [get_rid()]
	if _ignored_body_rid.is_valid():
		query.exclude.append(_ignored_body_rid)

	var splash_damage = int(float(_damage) * _aoe_damage_multiplier)
	var results = space_state.intersect_shape(query, 24)
	for result in results:
		var c = result.collider
		if c == hit_body:
			continue

		# Если стреляет игрок, дамажим врагов. Если враг - игрока.
		if _is_player:
			if c is Enemy:
				c.take_damage(splash_damage)
			elif c is Base and c.get("type_base") == 1:
				c.take_damage(splash_damage)
		else:
			if c is Player:
				c.take_damage(splash_damage)
			elif c is Base and c.get("type_base") == 0:
				c.take_damage(splash_damage)

func _on_screen_exited():
	var tween = create_tween()
	tween.tween_property(_bullet_sound, "volume_db", -80, 1.0)
	tween.finished.connect(queue_free)
