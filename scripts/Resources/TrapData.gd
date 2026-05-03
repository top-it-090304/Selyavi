class_name TrapData
extends Resource

@export_group("Identification")
@export var trap_type: int = 0 # 0: MINE, 1: WALL_TURRET, 2: EMP_RADAR

@export_group("Base Stats")
@export var damage: int = 25
@export var fire_rate: float = 0.25
@export var activation_radius: float = 400.0

@export_group("Visuals")
@export var sprite_texture: Texture2D
@export var base_texture: Texture2D
@export var sprite_scale: Vector2 = Vector2(1, 1)
@export var base_scale: Vector2 = Vector2(1, 1)
@export var rotation_speed: float = 0.0

@export_group("Special")
@export var mine_trigger_radius: float = 60.0
@export var mine_base_alpha: float = 0.3
