extends ColorRect

const STRIPE_SHADER = preload("res://assets/shaders/hidden_achievement_bar.gdshader")

func _ready():
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material = ShaderMaterial.new()
	shader_material.shader = STRIPE_SHADER
	material = shader_material
	resized.connect(_update_bar_size)
	_update_bar_size()

func _update_bar_size():
	(material as ShaderMaterial).set_shader_parameter("bar_size", size.max(Vector2.ONE))
