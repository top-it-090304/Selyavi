extends "res://scripts/Tank/Bullet.gd"

enum Kind { CLUSTER, FIRE, ELECTRIC_PAIR }

const FRAGMENT_SCENE = preload("res://scenes/Tank/Bullet.tscn")
const TRAIL_SPACING: float = 18.0
const CLUSTER_TRIGGER_RADIUS: float = 140.0

var kind: Kind = Kind.CLUSTER
var fire_trail: Node2D
var _finished: bool = false
var _trail_position: Vector2

func _ready():
	super._ready()
	_trail_position = global_position
	if kind == Kind.CLUSTER:
		var trigger = Area2D.new()
		trigger.name = "ClusterTrigger"
		trigger.collision_layer = 0
		trigger.collision_mask = 1
		trigger.monitorable = false
		var shape = CollisionShape2D.new()
		var circle = CircleShape2D.new()
		circle.radius = CLUSTER_TRIGGER_RADIUS
		shape.shape = circle
		trigger.add_child(shape)
		trigger.body_entered.connect(_on_cluster_proximity)
		add_child(trigger)
	if kind == Kind.FIRE and is_instance_valid(fire_trail):
		fire_trail.add_segment(global_position, global_position)

func init(type_bullet: int, player_owned: bool, damage: int = 0, ignored_rid: RID = RID(), custom_range: float = -1.0):
	# Характеристики лёгкой пули Егеря, изображение взрывного снаряда игрока.
	super.init(type_bullet, player_owned, damage, ignored_rid, custom_range)
	_bullet_sprite.texture = TEX_HE
	if kind == Kind.FIRE:
		var overlay = Sprite2D.new()
		overlay.texture = TEX_HE
		overlay.modulate = Color(1.8, 0.12, 0.05, 0.8)
		overlay.scale = Vector2.ONE * 1.04
		_bullet_sprite.add_child(overlay)
	elif kind == Kind.ELECTRIC_PAIR:
		_bullet_sprite.modulate = Color(1.4, 1.25, 0.65, 1.0)

func _physics_process(delta: float):
	if _finished: return
	super._physics_process(delta)
	if not _finished: _stamp_trail(false)

func _on_body_entered(body):
	if _finished: return
	if kind == Kind.CLUSTER and body is Player:
		_destroy()
		return
	super._on_body_entered(body)

func _on_cluster_proximity(body: Node2D):
	if kind == Kind.CLUSTER and body is Player: _destroy()

func _draw():
	if kind != Kind.CLUSTER: return
	draw_circle(Vector2.ZERO, CLUSTER_TRIGGER_RADIUS, Color(1, 1, 1, 0.05))
	draw_arc(Vector2.ZERO, CLUSTER_TRIGGER_RADIUS, 0, TAU, 96, Color(1, 1, 1, 0.9), 2.0, true)

func _stamp_trail(force: bool):
	if kind != Kind.FIRE or not is_instance_valid(fire_trail): return
	if not force and _trail_position.distance_to(global_position) < TRAIL_SPACING: return
	fire_trail.add_segment(_trail_position, global_position)
	_trail_position = global_position

func _destroy(hit_body: Node = null):
	if _finished: return
	_finished = true
	_stamp_trail(true)
	if kind == Kind.CLUSTER and (hit_body == null or hit_body is StaticBody2D or hit_body is TileMap or hit_body is TileMapLayer):
		# Столкновение может прийти во время обработки физики: осколки создаём после неё.
		hide()
		set_deferred("monitoring", false)
		_split_into_fragments.call_deferred()
	else:
		queue_free()

func _split_into_fragments():
	var field = get_parent() as Node2D
	if is_instance_valid(field) and not field.is_queued_for_deletion():
		for i in range(4):
			var fragment = FRAGMENT_SCENE.instantiate()
			fragment.position = field.to_local(global_position)
			fragment.rotation = randf_range(-PI, PI) - field.global_rotation
			field.add_child(fragment)
			fragment.init(LIGHT, false, int(_damage / 2.0), _ignored_body_rid, _max_range * 0.5)
	queue_free()

func _on_screen_exited():
	# Выход за камеру не заменяет попадание в стену или окончание дальности.
	pass
