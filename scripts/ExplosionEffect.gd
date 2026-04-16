extends Node2D

var _radius: float = 0.0
var _current_radius: float = 0.0
var _color: Color = Color.ORANGE
var _alpha: float = 1.0

func init(max_radius: float, color: Color):
	_radius = max_radius
	_color = color

	# Анимация расширения и затухания
	var tween = create_tween()
	tween.set_parallel(true)
	# Расширяем кольцо (используем TRANS_CIRC для "взрывного" старта)
	tween.tween_property(self, "_current_radius", _radius, 0.4).set_trans(Tween.TRANS_CIRC).set_ease(Tween.EASE_OUT)
	# Затухаем
	tween.tween_property(self, "_alpha", 0.0, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

	tween.set_parallel(false)
	tween.finished.connect(queue_free)

func _process(_delta):
	queue_redraw()

func _draw():
	var draw_color = _color
	draw_color.a = _alpha
	# Рисуем кольцо
	draw_arc(Vector2.ZERO, _current_radius, 0, TAU, 64, draw_color, 4.0, true)
	# Легкая заливка
	var fill_color = draw_color
	fill_color.a *= 0.15
	draw_circle(Vector2.ZERO, _current_radius, fill_color)
