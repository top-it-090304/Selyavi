@tool
extends BaseTrap

var _emp_entry_time: int = 0
const EMP_DEBOUNCE_MS: int = 400
const EFFECT_DURATION: float = 10.0

@onready var sprite = $Sprite2D
@onready var base_sprite = $BaseSprite
@onready var collision_shape = $CollisionShape2D

func _setup_from_data():
	if !data or !is_inside_tree(): return
	if sprite:
		sprite.texture = data.sprite_texture
		sprite.scale = data.sprite_scale * 0.5 # Уменьшили вращающуюся часть (было 0.7)
		sprite.modulate = Color(1.0, 0.3, 0.3, 1.0)
	if base_sprite:
		base_sprite.texture = data.base_texture
		base_sprite.scale = data.base_scale
		base_sprite.visible = data.base_texture != null

	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape = collision_shape.shape.duplicate()
		collision_shape.shape.radius = data.activation_radius

	modulate.a = 1.0 # Сам радар теперь всегда видим

func _draw():
	if Engine.is_editor_hint() or !data: return
	if is_instance_valid(_player):
		var dist = global_position.distance_to(_player.global_position)
		if dist < data.activation_radius * 1.5:
			var a_alpha = remap(dist, data.activation_radius * 1.5, data.activation_radius, 0.0, 0.15)
			var b_alpha = remap(dist, data.activation_radius * 1.5, data.activation_radius, 0.0, 0.4)
			draw_circle(Vector2.ZERO, data.activation_radius, Color(0.6, 0.2, 1.0, clamp(a_alpha, 0.0, 0.15)))
			draw_arc(Vector2.ZERO, data.activation_radius, 0, TAU, 64, Color(0.6, 0.2, 1.0, clamp(b_alpha, 0.0, 0.4)), 3.0, true)

func _physics_process(delta):
	if sprite: sprite.rotation += delta * (data.rotation_speed if data else 1.5)
	if Engine.is_editor_hint(): return

	super._physics_process(delta)
	if is_instance_valid(_player): queue_redraw()

func _on_body_entered(body):
	if body is Player:
		body.set_controls_inverted(true)
		_emp_entry_time = Time.get_ticks_msec()

func _on_body_exited(body):
	if body is Player:
		# Накладываем инверсию на 10 секунд после выхода
		body.set_controls_inverted(true, EFFECT_DURATION)
