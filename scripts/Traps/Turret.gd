@tool
extends BaseTrap

var _fire_timer: float = 0.0
var _bullet_scene = preload("res://scenes/Tank/Bullet.tscn")

@onready var sprite = $Sprite2D
@onready var base_sprite = $BaseSprite
@onready var muzzle_flash = $MuzzleFlash
@onready var collision_shape = $CollisionShape2D

func _setup_from_data():
	if !data or !is_inside_tree(): return
	if sprite:
		sprite.texture = data.sprite_texture
		sprite.scale = data.sprite_scale
	if base_sprite:
		base_sprite.texture = data.base_texture
		base_sprite.scale = data.base_scale
		base_sprite.visible = data.base_texture != null

	if collision_shape and collision_shape.shape is CircleShape2D:
		collision_shape.shape = collision_shape.shape.duplicate()
		collision_shape.shape.radius = data.activation_radius

	_setup_muzzle_flash()

func _setup_muzzle_flash():
	if not muzzle_flash: return
	var frames = SpriteFrames.new()
	frames.add_animation("Fire")
	frames.set_animation_speed("Fire", 25.0)
	frames.set_animation_loop("Fire", false)
	var textures = ["res://assets/future_tanks/PNG/Effects/Explosion_B.png", "res://assets/future_tanks/PNG/Effects/Explosion_C.png", "res://assets/future_tanks/PNG/Effects/Explosion_D.png", "res://assets/future_tanks/PNG/Effects/Explosion_E.png"]
	for path in textures: frames.add_frame("Fire", load(path))
	muzzle_flash.sprite_frames = frames
	muzzle_flash.visible = false
	muzzle_flash.scale = Vector2(0.4, 0.4)
	if not muzzle_flash.animation_finished.is_connected(_on_flash_finished):
		muzzle_flash.animation_finished.connect(_on_flash_finished)

func _on_flash_finished():
	muzzle_flash.visible = false

func _physics_process(delta):
	if Engine.is_editor_hint(): return
	super._physics_process(delta)
	if not is_instance_valid(_player): return

	var dist = global_position.distance_to(_player.global_position)
	if dist <= data.activation_radius:
		_fire_timer -= delta
		if _fire_timer <= 0:
			if _is_player_in_firing_line():
				_fire_bullet()
				_fire_timer = data.fire_rate

func _is_player_in_firing_line() -> bool:
	var forward = Vector2.UP.rotated(sprite.global_rotation)
	var to_player = (_player.global_position - global_position).normalized()
	# Проверяем, что игрок находится в узком конусе (ок. 10 градусов) перед турелью
	if forward.dot(to_player) > 0.985:
		var q = PhysicsRayQueryParameters2D.create(global_position, _player.global_position)
		q.exclude = [self]; q.collision_mask = 1
		return get_world_2d().direct_space_state.intersect_ray(q).is_empty()
	return false

func _fire_bullet():
	if AudioManager: AudioManager.play_bullet_sound(10, global_position)
	if muzzle_flash:
		muzzle_flash.position = Vector2(0, -45).rotated(sprite.rotation)
		muzzle_flash.rotation = sprite.rotation
		muzzle_flash.visible = true
		muzzle_flash.play("Fire")
	var b = _bullet_scene.instantiate()
	b.global_position = global_position + Vector2(0, -35).rotated(sprite.global_rotation)
	b.global_rotation = sprite.global_rotation
	get_parent().add_child(b)
	b.init(2, false, data.damage)
