extends Area2D

var _heal_amount: int = 25
var _sprite: Sprite2D
var _is_being_picked_up: bool = false
var _idle_tween: Tween

func _ready():
	# Настройка физики и визуальных элементов отложена, чтобы избежать ошибок
	# "Can't change this state while flushing queries", так как аптечка
	# спавнится в момент смерти врага (внутри физического шага)
	call_deferred("_setup_pickup")

func _setup_pickup():
	# Настройка коллизии
	var collision = CollisionShape2D.new()
	var circle_shape = CircleShape2D.new()
	circle_shape.radius = 30.0
	collision.shape = circle_shape
	add_child(collision)

	# Основной спрайт ящика
	_sprite = Sprite2D.new()
	var box_tex = load("res://assets/IngameAssets/EnemyDrop/free-icon-tool-box-479353.png")
	if box_tex:
		_sprite.texture = box_tex
	_sprite.scale = Vector2(0.1, 0.1)
	add_child(_sprite)

	# Анимация покачивания (сохраняем в переменную, чтобы остановить потом)
	_idle_tween = create_tween().set_loops()
	_idle_tween.tween_property(_sprite, "scale", Vector2(0.11, 0.11), 0.8)
	_idle_tween.tween_property(_sprite, "scale", Vector2(0.1, 0.1), 0.8)

	body_entered.connect(_on_body_entered)

	# Таймер до начала исчезновения (15 секунд всего, 11 секунд до начала моргания)
	get_tree().create_timer(11.0).timeout.connect(_start_disappear_sequence)

func _start_disappear_sequence():
	if _is_being_picked_up or not is_instance_valid(self):
		return

	# Останавливаем анимацию покачивания и фиксируем размер
	if _idle_tween:
		_idle_tween.kill()
	_sprite.scale = Vector2(0.1, 0.1)

	# Менее интенсивное моргание за 4 секунды до конца (от 1.0 до 0.4 прозрачности)
	var tween_blink = create_tween().set_loops(8) # 8 раз по 0.5 сек = 4 сек
	tween_blink.tween_property(self, "modulate:a", 0.4, 0.25)
	tween_blink.tween_property(self, "modulate:a", 1.0, 0.25)

	# Финальное удаление
	get_tree().create_timer(4.0).timeout.connect(func():
		if is_instance_valid(self) and not _is_being_picked_up:
			queue_free()
	)

func _on_body_entered(body):
	if _is_being_picked_up: return

	if body is Player:
		if body.has_method("take_heal"):
			body.take_heal(_heal_amount)
			_play_pickup_effect()

func _play_pickup_effect():
	_is_being_picked_up = true
	if _idle_tween:
		_idle_tween.kill()

	set_deferred("monitoring", false)

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2(2, 2), 0.3)
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.finished.connect(queue_free)
