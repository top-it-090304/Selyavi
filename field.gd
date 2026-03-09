extends Node2D
class_name Field

# region private fields
var _music_player: AudioStreamPlayer
# var _sound_player: AudioStreamPlayer
var _pause_scene: PackedScene
var _current_pause: Node
var _enemy_base: Base
var _player_base: Base
# endregion

func _ready():
	_music_player = get_node_or_null("MusicPlayer")
	# _sound_player = get_node_or_null("SoundPlayer")
	if _music_player != null:
		# _sound_player.bus = "SFX"
		_music_player.bus = "Music"
		_music_player.play()
	
	_enemy_base = $EnemyBase
	_player_base = $Base
	
	_player_base.base_state.connect(_on_player_base_destroy)
	
	_pause_scene = load("res://scenes/MenuScenes/PauseScreen.tscn")

func _on_player_base_destroy():
	_enemy_base.destroy()

func _on_TouchScreenButton_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/PauseScreen.tscn")
	# if _current_pause == null and _pause_scene != null:
	# 	_current_pause = _pause_scene.instantiate()
	# 	add_child(_current_pause)
