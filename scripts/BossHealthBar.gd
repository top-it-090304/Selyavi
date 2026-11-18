extends ProgressBar

const FRAME_TEXTURE: Texture2D = preload("res://assets/IngameAssets/HUD/BossHPFrame.png")

var _fill: ColorRect

func _ready():
	# Сохраняем стандартные значения HP и цвета, но рисуем заполнение внутри рамки.
	self_modulate.a = 0.0
	add_theme_stylebox_override("background", StyleBoxEmpty.new())
	var backing = Panel.new()
	var background = StyleBoxFlat.new()
	background.bg_color = Color(0.055, 0.065, 0.055, 1.0)
	background.set_corner_radius_all(6)
	backing.add_theme_stylebox_override("panel", background)
	backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backing.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backing)

	_fill = ColorRect.new()
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)
	value_changed.connect(func(_value): _update_fill())
	resized.connect(_update_fill)
	theme_changed.connect(_update_fill)
	_update_fill()

	# Независимая рамка рисуется поверх заполнения и не обрезается вместе с HP.
	var frame = NinePatchRect.new()
	frame.name = "BossHPFrame"
	frame.texture = FRAME_TEXTURE
	frame.patch_margin_left = 12
	frame.patch_margin_right = 12
	frame.patch_margin_top = 7
	frame.patch_margin_bottom = 7
	frame.draw_center = false
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(frame)

func _update_fill():
	if not is_instance_valid(_fill):
		return
	var fill_style = get_theme_stylebox("fill") as StyleBoxFlat
	if fill_style:
		_fill.color = fill_style.bg_color
	_fill.position = Vector2(12.0, 7.0)
	_fill.size = Vector2(maxf(size.x - 24.0, 0.0) * get_as_ratio(), maxf(size.y - 14.0, 0.0))
	_fill.visible = value > min_value
