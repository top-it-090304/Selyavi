extends Node2D

# region private fields
var _musicPlayer: AudioStreamPlayer
var _pauseScene: PackedScene
var _currentPause: Node
var _enemyBase: Base
var _playerBase: Base
# endregion

func _ready():
	_musicPlayer = get_node_or_null("MusicPlayer")
	if _musicPlayer != null:
		_musicPlayer.bus = "Music"
		_musicPlayer.play()
	
	_enemyBase = get_node("EnemyBase")
	_playerBase = get_node("Base")
	
	_playerBase.connect("base_state", self, "PlayerBaseDestroy")
	
	_pauseScene = load("res://scenes/MenuScenes/PauseScreen.tscn")

func PlayerBaseDestroy():
	if _enemyBase != null:
		_enemyBase.destroy()

func _on_TouchScreenButton_pressed():
	get_tree().change_scene("res://scenes/MenuScenes/PauseScreen.tscn")
