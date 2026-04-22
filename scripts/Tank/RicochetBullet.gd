extends Area2D

# --- Константы ---
const BULLET_SPEED: float = 9.0
const MAX_RANGE: float = 1200.0
const SPLASH_RADIUS: float = 100.0
const DEFAULT_BOUNCES: int = 2

# --- Переменные ---
var _velocity: Vector2 = Vector2.ZERO
var _damage: int = 30
var _splash_damage: int = 0
var _is_player: bool = true
var _bounces_left: int = DEFAULT_BOUNCES
var _traveled_distance: float = 0.0
var _ignored_body_rid: RID
var _destroyed: bool = false
var _has_ricocheted: bool = false
var _is_explosive: bool = false

var _bullet_sprite: Sprite2D

func is_player() -> bool:
	return true

func init(is_player_bullet: bool, damage_val: int, splash_dmg_val: int,
		ignored_rid: RID = RID(), bounces: int = DEFAULT_BOUNCES, explosive: bool = false):
	_is_player = true
	_damage = damage_val
	_splash_damage = splash_dmg_val
	_ignored_body_rid = ignored_rid
	_bounces_left = bounces
	_is_explosive = explosive

func _ready():
	_bullet_sprite = get_node_or_null("BulletSprite")
	_velocity = Vector2(0.0, -1.0).rotated(rotation)
	body_entered.connect(_on_body_entered)

func _process(_delta):
	if _destroyed: return
	_move()

func _move():
	var dir: Vector2 = _velocity.normalized()
	var step: Vector2 = dir * BULLET_SPEED
	var space_state = get_world_2d().direct_space_state
	var ray = PhysicsRayQueryParameters2D.create(global_position, global_position + dir * (BULLET_SPEED + 14.0))
	ray.exclude = [get_rid()]
	if _ignored_body_rid.is_valid(): ray.exclude.append(_ignored_body_rid)

	var hit = space_state.intersect_ray(ray)
	if hit:
		var collider = hit.collider
		if collider is Enemy:
			collider.take_damage(_damage)
			_handle_impact(hit.position)
			return
		elif _is_wall(collider):
			if _bounces_left > 0:
				_velocity = _velocity.bounce(hit.normal)
				rotation = _velocity.angle() + PI * 0.5
				_bounces_left -= 1
				_has_ricocheted = true
				_damage = int(ceil(_damage * 1.26))
				_splash_damage = int(ceil(max(1, _splash_damage) * 1.12))
				global_position = hit.position + hit.normal * 5.0
				_play_ricochet_fx()
			else:
				_handle_impact(hit.position)
			return

	global_position += step
	_traveled_distance += BULLET_SPEED
	if _traveled_distance >= MAX_RANGE: _destroy_silent()

func _handle_impact(impact_pos: Vector2):
	global_position = impact_pos
	if _is_explosive:
		_explode()
	else:
		_play_ricochet_fx()
		_destroy_silent()

func _is_wall(collider: Object) -> bool:
	if collider == null: return false
	if collider is Enemy: return false
	return collider is StaticBody2D or collider is TileMap or (collider.has_method("can_bullet_pass") and not collider.can_bullet_pass())

func _on_body_entered(body):
	if _destroyed: return
	if _ignored_body_rid.is_valid() and body.get_rid() == _ignored_body_rid: return
	if body is Enemy:
		body.take_damage(_damage)
		_handle_impact(global_position)

func _destroy(): _handle_impact(global_position)

func _destroy_silent():
	if _destroyed: return
	_destroyed = true
	queue_free()

func _explode():
	if _destroyed: return
	_destroyed = true
	var space_state = get_world_2d().direct_space_state
	var shape = CircleShape2D.new(); shape.radius = SPLASH_RADIUS
	var query = PhysicsShapeQueryParameters2D.new(); query.set_shape(shape); query.transform = Transform2D(0.0, global_position)
	var results = space_state.intersect_shape(query, 20)
	for result in results:
		var c = result.collider
		if c is Enemy: c.take_damage(_splash_damage)
		elif c is Base and c.get("type_base") == 1: c.take_damage(_splash_damage)
	_spawn_explosion_fx()
	queue_free()

func _play_ricochet_fx():
	var sparks = CPUParticles2D.new()
	sparks.global_position = global_position
	sparks.emitting = true; sparks.one_shot = true; sparks.amount = 10; sparks.lifetime = 0.22; sparks.explosiveness = 1.0; sparks.scale_amount_min = 0.12; sparks.scale_amount_max = 0.30; sparks.color = Color(1.0, 0.8, 0.2, 1.0)
	get_parent().add_child(sparks)
	get_tree().create_timer(1.0).timeout.connect(sparks.queue_free)

func _spawn_explosion_fx():
	var expl = CPUParticles2D.new()
	expl.global_position = global_position
	expl.emitting = true; expl.one_shot = true; expl.amount = 30; expl.lifetime = 0.6; expl.explosiveness = 0.95; expl.spread = 180.0; expl.initial_velocity_min = 100.0; expl.initial_velocity_max = 250.0; expl.scale_amount_min = 0.3; expl.scale_amount_max = 0.8; expl.gravity = Vector2(0.0, -50.0)
	get_parent().add_child(expl)
	get_tree().create_timer(2.0).timeout.connect(expl.queue_free)
