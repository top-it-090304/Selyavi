@tool
class_name BaseTrap
extends Area2D

@export var data: TrapData:
	set(val):
		data = val
		_setup_from_data()

var _player: Player = null

func _ready():
	if not Engine.is_editor_hint():
		body_entered.connect(_on_body_entered)
		body_exited.connect(_on_body_exited)
	_setup_from_data()

func _setup_from_data():
	pass

func _physics_process(_delta):
	if Engine.is_editor_hint(): return
	if not is_instance_valid(_player):
		_player = get_tree().get_first_node_in_group("players") as Player

func _on_body_entered(_body):
	pass

func _on_body_exited(_body):
	pass
