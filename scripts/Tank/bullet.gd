extends Area2D
class_name Bullet

# region private fields
var bullet_speed: int = 7:
	set(value):
		if value > 0 and value <= 30:
			bullet_speed = value
var velocity: Vector2 = Vector2.ZERO
var bullet_sound: AudioStreamPlayer
var tween_bullet: Tween
var visibility_bullet: VisibilityNotifier2D
var type_bullet: int
var bullet_sprite: Sprite
var damage: int
var is_player: bool
# endregion

func _ready():
	bullet_sprite = $BulletSprite
	bullet_sound = $PlasmaGunSound
	velocity = Vector2(0, -1).rotated(rotation)
	visibility_bullet = $VisibilityNotifier2D
	tween_bullet = Tween.new()
	add_child(tween_bullet)
	
	body_entered.connect(_on_body_entered)
	visibility_bullet.screen_exited.connect(_on_screen_exited)

func move():
	position += velocity * bullet_speed

func fade_sound():
	if tween_bullet == null:
		return
	
	if not tween_bullet.is_inside_tree():
		queue_free()
		return
	
	if tween_bullet.tween_completed.is_connected(_on_tween_complete):
		tween_bullet.tween_completed.disconnect(_on_tween_complete)
	
	tween_bullet.interpolate_property(
		bullet_sound,
		"volume_db",
		bullet_sound.volume_db,
		-80,
		1.0,
		Tween.TRANS_LINEAR,
		Tween.EASE_IN_OUT
	)
	
	tween_bullet.start()
	tween_bullet.tween_completed.connect(_on_tween_complete)

func _on_tween_complete(obj: Object, key: NodePath):
	bullet_sound.stop()
	bullet_sound.volume_db = 0
	queue_free()

func _on_screen_exited():
	fade_sound()

func _on_body_entered(body: Node):
	if body is Player and not is_player:
		body.take_damage(damage)
		destroy()
	elif body is Enemy and is_player:
		body.take_damage(damage)
		destroy()
	elif body is IngameWall:
		if body.can_bullet_pass():
			return
		elif body.destroyable():
			body.destroy()
			destroy()
		else:
			destroy()
	elif body is Base:
		destroy()
	elif body is StaticBody2D:
		destroy()

func destroy():
	queue_free()

func update_type():
	match type_bullet:
		0: # TypeBullet.Plasma
			bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Plasma.png")
			bullet_speed = 7
			damage = 5
		1: # TypeBullet.Medium
			bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Medium_Shell.png")
			bullet_speed = 4
			damage = 10
		2: # TypeBullet.Light
			bullet_sprite.texture = load("res://assets/future_tanks/PNG/Effects/Light_Shell.png")
			bullet_speed = 6
			damage = 7
	
	if AudioManager.instance != null:
		AudioManager.instance.play_bullet_sound(type_bullet, global_position)

func init(p_type_bullet: int, p_is_player: bool):
	type_bullet = p_type_bullet
	is_player = p_is_player
	update_type()

func _process(delta):
	move()
