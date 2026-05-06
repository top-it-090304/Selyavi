extends Enemy

const ARTILLERY_SCENE: PackedScene = preload("res://scenes/Tank/ArtilleryTarget.tscn")

var _hp_bar: ProgressBar
var _hp_bar_label: Label

func _ready():
	_type_enemy = TypeEnemy.BOSS
	super._ready()

	_hp = 500
	_max_hp = 500
	_damage = 55
	_fire_rate = 2.6
	_spread = 0.35
	_patrol_speed = 0
	_chase_speed = 0
	_notice_range = 2600.0
	_attack_range = 2400.0
	_shoot_timer.wait_time = _fire_rate

	if _body:
		_body.texture = load("res://assets/future_tanks/PNG/Hulls_Color_D/Hull_04.png")
		_body.self_modulate = Color(0.78, 0.74, 0.98, 1.0)
	if _gun:
		_gun.texture = load("res://assets/future_tanks/PNG/Weapon_Color_D/Gun_08.png")
		_gun.self_modulate = Color(0.9, 0.87, 1.0, 1.0)

	_setup_hp_bar()

func _setup_hp_bar():
	var canvas := CanvasLayer.new()
	add_child(canvas)

	_hp_bar = ProgressBar.new()
	_hp_bar.max_value = _max_hp
	_hp_bar.value = _hp
	_hp_bar.show_percentage = false
	_hp_bar.custom_minimum_size = Vector2(520, 26)
	_hp_bar.anchor_left = 0.5
	_hp_bar.anchor_right = 0.5
	_hp_bar.anchor_top = 1.0
	_hp_bar.anchor_bottom = 0.1
	_hp_bar.offset_left = -260.0
	_hp_bar.offset_right = 260.0
	_hp_bar.offset_top = 22.0
	_hp_bar.offset_bottom = 50.0

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.07, 0.12, 0.45)
	bg.set_border_width_all(2)
	bg.border_color = Color(0.5, 0.5, 0.95, 0.55)
	_hp_bar.add_theme_stylebox_override("background", bg)

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.52, 0.5, 0.98, 0.72)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	canvas.add_child(_hp_bar)

	_hp_bar_label = Label.new()
	_hp_bar_label.text = "ARTU"
	_hp_bar_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_bar_label.add_theme_color_override("font_color", Color(0.78, 0.75, 1.0, 0.92))
	_hp_bar_label.custom_minimum_size = Vector2(520, 20)
	_hp_bar_label.anchor_left = 0.5
	_hp_bar_label.anchor_right = 0.5
	_hp_bar_label.anchor_top = 1.0
	_hp_bar_label.anchor_bottom = 0.1
	_hp_bar_label.offset_left = -260.0
	_hp_bar_label.offset_right = 260.0
	_hp_bar_label.offset_top = 0.0
	_hp_bar_label.offset_bottom = 22.0
	canvas.add_child(_hp_bar_label)

func take_damage(damage: int):
	super.take_damage(damage)
	if _hp_bar:
		_hp_bar.value = _hp

func _check_and_fire():
	var target: Node2D = _get_current_target() as Node2D
	if target == null:
		return

	var dist := global_position.distance_to(target.global_position)
	if dist > _attack_range:
		return

	# Boss can shoot without direct line of sight.
	if _reaction_timer >= 0.9:
		_fire_at_pos(target.global_position)

func _fire_at_pos(pos: Vector2):
	if _shoot_timer.time_left > 0.0 or ARTILLERY_SCENE == null:
		return

	var pattern := randi() % 3
	match pattern:
		0:
			_spawn_shell(pos, _damage, 130.0, 2.2)
		1:
			for _i in range(3):
				var offset := Vector2(randf_range(-170.0, 170.0), randf_range(-170.0, 170.0))
				_spawn_shell(pos + offset, int(round(_damage * 0.72)), 88.0, 1.55)
		2:
			_spawn_shell(pos, int(round(_damage * 1.55)), 175.0, 2.8)

	if AudioManager:
		AudioManager.play_bullet_sound(2, global_position)
	if _shot_flash:
		_shot_flash.play("Fire")

	_shoot_timer.start(_fire_rate)

func _spawn_shell(target_pos: Vector2, dmg: int, radius: float, duration: float):
	var artillery := ARTILLERY_SCENE.instantiate()
	var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
	artillery.global_position = target_pos + jitter * randf_range(0.0, _spread * 500.0)
	artillery.set("_damage", dmg)
	artillery.set("_radius", radius)
	artillery.set("_duration", duration)
	get_parent().add_child(artillery)
