extends Area2D

enum TrapType { MINE, WALL_TURRET, EMP_RADAR }

@export var data: TrapData

var _player: Player = null
var _fire_timer: float = 0.0
var _bullet_scene = preload("res://scenes/Tank/Bullet.tscn")
var _explosion_script = preload("res://scripts/ExplosionEffect.gd")
var _emp_entry_time: int = 0
const EMP_DEBOUNCE_MS: int = 400

@onready var sprite: Sprite2D = $Sprite2D
@onready var base_sprite: Sprite2D = $BaseSprite
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var muzzle_flash: AnimatedSprite2D = get_node_or_null("MuzzleFlash")

func _ready():
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	if data:
		_setup_from_data()
	else:
		push_warning("Trap: No TrapData assigned!")

	_setup_muzzle_flash()

func _setup_from_data():
	if sprite:
		sprite.texture = data.sprite_texture
		sprite.scale = data.sprite_scale

	if base_sprite:
		base_sprite.texture = data.base_texture
		base_sprite.scale = data.base_scale
		base_sprite.visible = data.base_texture != null

	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape = collision_shape.shape.duplicate()
		if data.trap_type == TrapType.MINE:
			collision_shape.shape.radius = data.mine_trigger_radius
		else:
			collision_shape.shape.radius = data.activation_radius

	if data.trap_type == TrapType.MINE:
		modulate.a = data.mine_base_alpha
	elif data.trap_type == TrapType.EMP_RADAR:
		sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
		modulate.a = 0.0

func _setup_muzzle_flash():
	if not muzzle_flash: return
	var frames = SpriteFrames.new()
	frames.add_animation("Fire")
	frames.set_animation_speed("Fire", 25.0)
	frames.set_animation_loop("Fire", false)
	var textures = [
		"res://assets/future_tanks/PNG/Effects/Explosion_B.png",
		"res://assets/future_tanks/PNG/Effects/Explosion_C.png",
		"res://assets/future_tanks/PNG/Effects/Explosion_D.png",
		"res://assets/future_tanks/PNG/Effects/Explosion_E.png"
	]
	for path in textures: frames.add_frame("Fire", load(path))
	muzzle_flash.sprite_frames = frames
	muzzle_flash.visible = false
	muzzle_flash.scale = Vector2(0.4, 0.4)

func _draw():
	if !data or data.trap_type != TrapType.EMP_RADAR: return
	var area_color = Color(0.6, 0.2, 1.0, 0.1)
	var border_color = Color(0.6, 0.2, 1.0, 0.3)
	draw_circle(Vector2.ZERO, data.activation_radius, area_color)
	draw_arc(Vector2.ZERO, data.activation_radius, 0, TAU, 64, border_color, 3.0, true)

func _physics_process(delta):
	if !data: return

	# Вращение радара ВНЕ условий поиска игрока
	if data.trap_type == TrapType.EMP_RADAR and sprite:
		sprite.rotation += delta * data.rotation_speed

	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("players") as Player
		if not is_instance_valid(_player): return

	var dist = global_position.distance_to(_player.global_position)

	match data.trap_type:
		TrapType.MINE:
			_process_mine_visibility(dist)
		TrapType.WALL_TURRET:
			_process_turret(delta, dist)
		TrapType.EMP_RADAR:
			_process_emp_radar_visuals(dist)

func _process_mine_visibility(dist: float):
	if dist < data.activation_radius:
		var target_alpha = remap(dist, data.activation_radius, 50.0, data.mine_base_alpha, 0.9)
		modulate.a = clamp(target_alpha, data.mine_base_alpha, 1.0)
	else:
		modulate.a = data.mine_base_alpha

func _process_turret(delta: float, dist: float):
	if dist <= data.activation_radius:
		var target_angle = (_player.global_position - global_position).angle() + PI/2
		sprite.global_rotation = lerp_angle(sprite.global_rotation, target_angle, 8.0 * delta)
		_fire_timer -= delta
		if _fire_timer <= 0:
			if _is_line_of_sight_clear():
				_fire_bullet()
				_fire_timer = data.fire_rate

func _process_emp_radar_visuals(dist: float):
	if dist < data.activation_radius * 1.5:
		var target_a = remap(dist, data.activation_radius * 1.5, data.activation_radius, 0.0, 1.0)
		modulate.a = clamp(target_a, 0.0, 1.0)
		queue_redraw()
	else:
		modulate.a = 0.0

func _is_line_of_sight_clear() -> bool:
	var q = PhysicsRayQueryParameters2D.create(global_position, _player.global_position)
	q.exclude = [self]; q.collision_mask = 1
	return get_world_2d().direct_space_state.intersect_ray(q).is_empty()

func _fire_bullet():
	if AudioManager: AudioManager.play_bullet_sound(10, global_position)
	if muzzle_flash:
		muzzle_flash.position = Vector2(0, -45).rotated(sprite.rotation)
		muzzle_flash.rotation = sprite.rotation
		muzzle_flash.visible = true
		muzzle_flash.play("Fire")
	var b = _bullet_scene.instantiate()
	b.global_position = global_position + Vector2(0, -35).rotated(sprite.global_rotation)
	b.global_rotation = sprite.global_rotation
	get_parent().add_child(b); b.init(2, false, data.damage)

func _on_body_entered(body):
	if !data or !body is Player: return
	match data.trap_type:
		TrapType.MINE: _explode_mine(body)
		TrapType.EMP_RADAR:
			body.set_controls_inverted(true)
			_emp_entry_time = Time.get_ticks_msec()

func _on_body_exited(body):
	if !data: return
	if body is Player and data.trap_type == TrapType.EMP_RADAR:
		var elapsed = Time.get_ticks_msec() - _emp_entry_time
		if elapsed < EMP_DEBOUNCE_MS:
			await get_tree().create_timer((EMP_DEBOUNCE_MS - elapsed) / 1000.0).timeout
		if is_instance_valid(body) and not overlaps_body(body):
			body.set_controls_inverted(false)

func _explode_mine(target: Player):
	if target.has_method("take_damage"): target.take_damage(data.damage)
	var effect = Node2D.new(); effect.set_script(_explosion_script); get_parent().add_child(effect); effect.global_position = global_position
	if effect.has_method("init"): effect.init(130.0, Color(1, 0.5, 0.1, 0.8))
	if AudioManager: AudioManager.play_bullet_sound(1, global_position)
	visible = false; collision_layer = 0; collision_mask = 0
	get_tree().create_timer(1.0).timeout.connect(queue_free)
