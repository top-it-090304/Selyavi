extends Sprite2D

const MAX_ANGLE: float = 8.0
const MIN_DURATION: float = 0.9
const MAX_DURATION: float = 1.8

var _rotation_tween: Tween

func _ready():
	_choose_rotation()

func _choose_rotation():
	var next_angle = randf_range(-MAX_ANGLE, MAX_ANGLE)
	_rotation_tween = create_tween()
	_rotation_tween.tween_property(self, "rotation_degrees", next_angle, randf_range(MIN_DURATION, MAX_DURATION)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_rotation_tween.finished.connect(_choose_rotation)
