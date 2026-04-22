extends Area2D

# --- Константы ---
const BULLET_SPEED: float = 8.0
const MAX_RANGE: float = 2200.0
const SPLASH_RADIUS: float = 125.0
const DEFAULT_BOUNCES: int = 3

# --- Переменные ---
var _velocity: Vector2 = Vector2.ZERO
var _damage: int = 30
var _splash_damage: int = 50
var _is_player: bool = false
var _bounces_left: int = DEFAULT_BOUNCES
var _traveled_distance: float = 0.0
var _ignored_body_rid: RID
var _destroyed: bool = false
var _has_ricocheted: bool = false
var _is_explosive: bool = false

var _bullet_sprite: Sprite2D
var _trail_particles: CPUParticles2D
var _halo_visual: Node2D

func is_player() -> bool:
	return false

func init(is_player_bullet: bool, damage_val: int, splash_dmg_val: int,
		ignored_rid: RID = RID(), bounces: int = DEFAULT_BOUNCES, explosive: bool = false):
	_is_player = false
	_damage = damage_val
	_splash_damage = splash_dmg_val
	_ignored_body_rid = ignored_rid
	_bounces_left = bounces
	_is_explosive = explosive
	_update_visuals()

func _ready():
	_bullet_sprite = get_node_or_null("BulletSprite")
	_velocity = Vector2(0.0, -1.0).rotated(rotation)
	body_entered.connect(_on_body_entered)
	_update_visuals()

func _update_visuals():
	if not is_inside_tree() or not _bullet_sprite: return
	if _is_explosive: _setup_explosive_visuals()
	else: _setup_normal_visuals()

func _setup_normal_visuals():
	if _bullet_sprite:
		_bullet_sprite.modulate = Color(0.3, 0.7, 2.0)
		_bullet_sprite.scale = Vector2(1.0, 1.0)
		var old = _bullet_sprite.get_node_or_null("ExplosiveOverlay")
		if old: old.queue_free()

func _setup_explosive_visuals():
	if _bullet_sprite:
		_bullet_sprite.modulate = Color(1, 1, 1)
		_bullet_sprite.scale = Vector2(1.6, 1.6)
		var overlay = _bullet_sprite.get_node_or_null("ExplosiveOverlay")
		if not overlay:
			overlay = Sprite2D.new()
			overlay.name = "ExplosiveOverlay"
			overlay.texture = _bullet_sprite.texture
			_bullet_sprite.add_child(overlay)
		overlay.modulate = Color(2.5, 0.1, 0.1, 0.8)
		overlay.scale = Vector2(1.05, 1.05)
		var tw = create_tween().set_loops()
		tw.tween_property(overlay, "modulate:a", 0.3, 0.25); tw.tween_property(overlay, "modulate:a", 0.9, 0.25)

	if not has_node("Halo"):
		_halo_visual = Node2D.new(); _halo_visual.name = "Halo"; _halo_visual.set_script(load("res://scripts/ExplosionEffect.gd")); add_child(_halo_visual)
		var t = Timer.new(); t.wait_time = 0.2; t.autostart = true; add_child(t)
		t.timeout.connect(func(): if is_instance_valid(_halo_visual): _halo_visual.init(45.0, Color(1, 0, 0, 0.35)))

	if not has_node("TrailParticles"):
		_trail_particles = CPUParticles2D.new(); _trail_particles.name = "TrailParticles"; add_child(_trail_particles)
		_trail_particles.amount = 40; _trail_particles.lifetime = 0.5; _trail_particles.local_coords = false; _trail_particles.texture = load("res://assets/future_tanks/PNG/Effects/Smoke_A.png"); _trail_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE; _trail_particles.emission_sphere_radius = 8.0; _trail_particles.gravity = Vector2.ZERO; _trail_particles.initial_velocity_min = 50.0; _trail_particles.initial_velocity_max = 100.0; _trail_particles.scale_amount_min = 0.1; _trail_particles.scale_amount_max = 0.3
		var grad = Gradient.new(); grad.set_color(0, Color(1.0, 0.2, 0.1, 1.0)); grad.add_point(1.0, Color(0.1, 0.1, 0.1, 0.0)); _trail_particles.color_ramp = grad

func _process(_delta):
	if _destroyed: return
	_move()

func _move():
	var dir: Vector2 = _velocity.normalized()
	var step: Vector2 = dir * BULLET_SPEED
	var space_state = get_world_2d().direct_space_state
	var ray = PhysicsRayQueryParameters2D.create(global_position, global_position + dir * 25.0)
	ray.exclude = [get_rid(), _ignored_body_rid]
	var hit = space_state.intersect_ray(ray)

	if hit:
		var collider = hit.collider
		if collider is Player:
			collider.take_damage(_damage)
			_handle_impact(hit.position)
		elif _is_wall(collider):
			if _bounces_left > 0:
				if _is_explosive and _bounces_left > 1: _explode_at_bounce()
				_velocity = _velocity.bounce(hit.normal); rotation = _velocity.angle() + PI * 0.5; _bounces_left -= 1
				global_position = hit.position + hit.normal * 5.0; _play_ricochet_fx()
			else: _handle_impact(hit.position)
		return

	global_position += step
	_traveled_distance += BULLET_SPEED
	if _traveled_distance >= MAX_RANGE: _destroy_silent()

func _handle_impact(impact_pos: Vector2):
	global_position = impact_pos
	if _is_explosive: _explode()
	else:
		_play_ricochet_fx()
		_destroy_silent()

func _is_wall(collider: Object) -> bool:
	return collider is StaticBody2D or collider is TileMap or (collider.has_method("can_bullet_pass") and not collider.can_bullet_pass())

func _on_body_entered(body):
	if _destroyed: return
	if body is Player:
		body.take_damage(_damage)
		_handle_impact(global_position)

func _destroy(): _handle_impact(global_position)

func _destroy_silent():
	if _destroyed: return
	_destroyed = true; queue_free()

func _explode_at_bounce():
	_play_shockwave()
	_spawn_explosion_fx_lite()
	var space_state = get_world_2d().direct_space_state
	var shape = CircleShape2D.new(); shape.radius = SPLASH_RADIUS
	var query = PhysicsShapeQueryParameters2D.new(); query.set_shape(shape); query.transform = Transform2D(0.0, global_position)
	var results = space_state.intersect_shape(query, 10)
	for result in results:
		if result.collider is Player: result.collider.take_damage(int(_splash_damage * 0.7))

func _explode():
	if _destroyed: return
	_destroyed = true
	var space_state = get_world_2d().direct_space_state
	var shape = CircleShape2D.new(); shape.radius = SPLASH_RADIUS
	var query = PhysicsShapeQueryParameters2D.new(); query.set_shape(shape); query.transform = Transform2D(0.0, global_position)
	var results = space_state.intersect_shape(query, 20)
	for result in results:
		var c = result.collider
		if c is Player: c.take_damage(_splash_damage)
		elif c is Base and c.get("type_base") == 0: c.take_damage(_splash_damage)
	_play_shockwave(); _spawn_explosion_fx(); queue_free()

func _play_shockwave():
	var effect_script = load("res://scripts/ExplosionEffect.gd")
	if not effect_script: return
	var effect = Node2D.new(); effect.set_script(effect_script); get_parent().add_child(effect); effect.global_position = global_position; effect.z_index = 5
	if effect.has_method("init"): effect.init(SPLASH_RADIUS, Color(1, 0.5, 0.1, 0.8))

func _play_ricochet_fx():
	var sparks = CPUParticles2D.new(); sparks.global_position = global_position; sparks.emitting = true; sparks.one_shot = true; sparks.amount = 10; sparks.lifetime = 0.22; sparks.explosiveness = 1.0; sparks.scale_amount_min = 0.12; sparks.scale_amount_max = 0.30; sparks.color = Color(1.0, 0.8, 0.2, 1.0)
	get_parent().add_child(sparks); get_tree().create_timer(1.0).timeout.connect(sparks.queue_free)

func _spawn_explosion_fx_lite():
	var sparks = CPUParticles2D.new(); sparks.global_position = global_position; sparks.emitting = true; sparks.one_shot = true; sparks.amount = 20; sparks.lifetime = 0.4; sparks.explosiveness = 1.0; sparks.scale_amount_min = 0.2; sparks.scale_amount_max = 0.5; sparks.color = Color(1.0, 0.4, 0.0)
	get_parent().add_child(sparks); get_tree().create_timer(1.0).timeout.connect(sparks.queue_free)

func _spawn_explosion_fx():
	var expl = CPUParticles2D.new(); expl.global_position = global_position; expl.emitting = true; expl.one_shot = true; expl.amount = 40; expl.lifetime = 0.75; expl.explosiveness = 0.95; expl.spread = 180.0; expl.initial_velocity_min = 130.0; expl.initial_velocity_max = 340.0; expl.scale_amount_min = 0.45; expl.scale_amount_max = 1.1; expl.gravity = Vector2(0.0, -50.0)
	var grad = Gradient.new(); grad.set_color(0, Color(1.0, 0.95, 0.3, 1.0)); grad.add_point(0.25, Color(1.0, 0.4, 0.0, 0.95)); grad.add_point(0.6, Color(0.7, 0.1, 0.0, 0.6)); grad.add_point(1.0, Color(0.15, 0.15, 0.15, 0.0)); expl.color_ramp = grad; get_parent().add_child(expl); get_tree().create_timer(2.0).timeout.connect(expl.queue_free)
	var snd = AudioStreamPlayer2D.new(); snd.stream = load("res://assets/sounds/vystrel-tanka.mp3"); snd.volume_db = 3.0; snd.pitch_scale = 0.55; snd.bus = "SFX"; get_parent().add_child(snd); snd.global_position = global_position; snd.play(); snd.finished.connect(snd.queue_free)
