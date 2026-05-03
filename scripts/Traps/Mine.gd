extends BaseTrap

var _explosion_script = preload("res://scripts/ExplosionEffect.gd")

@onready var sprite = $Sprite2D
@onready var collision_shape = $CollisionShape2D

func _setup_from_data():
	if sprite:
		sprite.texture = data.sprite_texture
		sprite.scale = data.sprite_scale
		modulate.a = data.mine_base_alpha

	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape = collision_shape.shape.duplicate()
		collision_shape.shape.radius = data.mine_trigger_radius

func _physics_process(delta):
	super._physics_process(delta)
	if not is_instance_valid(_player): return

	var dist = global_position.distance_to(_player.global_position)
	if dist < data.activation_radius:
		var target_alpha = remap(dist, data.activation_radius, 50.0, data.mine_base_alpha, 0.9)
		modulate.a = clamp(target_alpha, data.mine_base_alpha, 1.0)
	else:
		modulate.a = data.mine_base_alpha

func _on_body_entered(body):
	if body is Player:
		_explode(body)

func _explode(target):
	if target.has_method("take_damage"):
		target.take_damage(data.damage)

	var effect = Node2D.new()
	effect.set_script(_explosion_script)
	get_parent().add_child(effect)
	effect.global_position = global_position
	if effect.has_method("init"):
		effect.init(130.0, Color(1, 0.5, 0.1, 0.8))

	if AudioManager:
		AudioManager.play_bullet_sound(1, global_position)

	visible = false
	set_physics_process(false)
	collision_layer = 0
	collision_mask = 0
	get_tree().create_timer(1.0).timeout.connect(queue_free)
