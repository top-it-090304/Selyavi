class_name EnemyData
extends Resource

@export_group("Base Stats")
@export var hp: int = 100
@export var hp_early_levels: int = 0 # ХП для уровней 1-5. Если 0, используется обычное hp.
@export var damage: int = 20
@export var fire_rate: float = 1.0
@export var spread: float = 0.1
@export var reward_money: int = 100

@export_group("Spawn Settings")
@export var is_special: bool = false # Особый бот
@export var is_boss: bool = false # Является боссом
@export var can_be_spawned_by_base: bool = true # Может ли база спавнить этого бота
@export var enemy_type: int = -1 # Тип врага (Enemy.TypeEnemy). Если -1, определится по поведению.

@export_group("Movement")
@export var patrol_speed: int = 90
@export var chase_speed: int = 60
@export var notice_range: float = 800.0
@export var attack_range: float = 450.0

@export_group("Visuals")
@export var hull_texture: Texture2D
@export var gun_texture: Texture2D
@export var gun_offset: float = 40.0
@export var scale: Vector2 = Vector2(1, 1)
