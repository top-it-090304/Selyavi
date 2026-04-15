class_name Tank
extends CharacterBody2D

# Общие сигналы
signal tank_health_changed(current, max_hp)

# Временное поле для отладки (будет видно в инспекторе)
@export var last_damage_received: int = 0

# region Общие поля
var _hp: int = 100 # Дефолтное значение для безопасности
var _max_hp: int = 100
var _damage: int = 30
var _armor: float = 0.0
var _bullet_scene: PackedScene

var _body: Sprite2D
var _gun: Sprite2D
var _bullet_position: Marker2D
var _shoot_timer: Timer
var _moving_sound: AudioStreamPlayer
var _smoke_particles: CPUParticles2D
var _fade_tween: Tween
var _hit_flash_tween: Tween
var _normal_movement_volume: float = 0.0
var _is_moving: bool = false
var _is_invulnerable: bool = false

# Баффы от базы
var _base_damage_mult: float = 1.0
var _base_armor_bonus: float = 0.0
var _base_rof_mult: float = 1.0
# endregion

func _init_base_tank():
	_bullet_scene = load("res://scenes/Tank/Bullet.tscn")
	_body = get_node_or_null("BodyTank")
	_gun = get_node_or_null("BodyTank/Gun")
	_bullet_position = get_node_or_null("BodyTank/Gun/BulletPosition")
	_moving_sound = get_node_or_null("MovingSound")

	if _moving_sound:
		_normal_movement_volume = _moving_sound.volume_db
		_moving_sound.bus = "SFX"

	_shoot_timer = Timer.new()
	_shoot_timer.one_shot = true
	add_child(_shoot_timer)

	_setup_damage_effects()

func take_damage(damage: int):
	if _is_invulnerable: return

	last_damage_received = damage # Сохраняем для инспектора
	var final_damage = float(damage)

	if not is_in_group("enemies"):
		var total_armor = clamp(_armor + _base_armor_bonus, -0.9, 0.95)
		final_damage = damage * (1.0 - total_armor)

	_hp -= int(final_damage)
	tank_health_changed.emit(_hp, _max_hp)
	_play_body_hit_flash()
	_update_damage_visuals()
	if _hp <= 0:
		_destroy()

func _play_body_hit_flash():
	if _body == null: return
	if _hit_flash_tween != null and _hit_flash_tween.is_running():
		_hit_flash_tween.kill()
	_hit_flash_tween = create_tween()
	_hit_flash_tween.tween_property(_body, "modulate", Color(4.5, 4.5, 4.5, 1.0), 0.05)
	_hit_flash_tween.tween_property(_body, "modulate", Color(1, 1, 1, 1.0), 0.07)

func apply_base_buffs(damage_mult: float, armor_bonus: float, rof_mult: float):
	_base_damage_mult = damage_mult
	_base_armor_bonus = armor_bonus
	_base_rof_mult = rof_mult

func _setup_damage_effects():
	_smoke_particles = CPUParticles2D.new()
	add_child(_smoke_particles)
	_smoke_particles.position = Vector2.ZERO
	_smoke_particles.emitting = false
	_smoke_particles.amount = 20
	_smoke_particles.lifetime = 0.8
	_smoke_particles.texture = load("res://assets/future_tanks/PNG/Effects/Smoke_A.png")
	_smoke_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	_smoke_particles.emission_sphere_radius = 20.0
	_smoke_particles.spread = 180.0
	_smoke_particles.gravity = Vector2(0, -100)
	_smoke_particles.initial_velocity_min = 20.0
	_smoke_particles.initial_velocity_max = 50.0
	_smoke_particles.scale_amount_min = 0.1
	_smoke_particles.scale_amount_max = 0.3
	_smoke_particles.color = Color(0.3, 0.3, 0.3, 0.6)

	var curve = Gradient.new()
	curve.add_point(0.0, Color(0.5, 0.5, 0.5, 0.0))
	curve.add_point(0.2, Color(0.2, 0.2, 0.2, 0.7))
	curve.add_point(1.0, Color(0.1, 0.1, 0.1, 0.0))
	_smoke_particles.color_ramp = curve

func _update_damage_visuals():
	if _max_hp <= 0: return
	var health_percent = float(_hp) / float(_max_hp)

	if health_percent <= 0.5:
		_smoke_particles.emitting = true
		if health_percent <= 0.25:
			_smoke_particles.amount = 40
			_smoke_particles.color = Color(0.1, 0.1, 0.1, 0.8)
		else:
			_smoke_particles.amount = 20
			_smoke_particles.color = Color(0.3, 0.3, 0.3, 0.5)
	else:
		_smoke_particles.emitting = false

func _handle_movement_sound(movement_velocity: Vector2):
	var is_moving_now = movement_velocity.length() > 0.1
	if is_moving_now:
		if not _is_moving:
			if _fade_tween != null and _fade_tween.is_running(): _fade_tween.kill()
			if _moving_sound:
				_moving_sound.volume_db = _normal_movement_volume
				if not _moving_sound.playing: _moving_sound.play()
			_is_moving = true
	else:
		if _is_moving:
			_is_moving = false
			if _moving_sound and _moving_sound.playing: _fade_sound()

func _fade_sound():
	if _fade_tween != null and _fade_tween.is_running(): _fade_tween.kill()
	if _moving_sound:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_moving_sound, "volume_db", -80.0, 0.3)
		_fade_tween.finished.connect(func(): _moving_sound.stop(); _moving_sound.volume_db = _normal_movement_volume)

func _destroy():
	queue_free()
