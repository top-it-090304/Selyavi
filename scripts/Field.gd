extends Node2D

var _musicPlayer: AudioStreamPlayer
var _pauseScene: PackedScene
var _currentPause: Node
var _enemyBase: Base
var _playerBase: Base

func _ready():
	_musicPlayer = get_node_or_null("MusicPlayer")
	if _musicPlayer != null:
		_musicPlayer.bus = "Music"
		_musicPlayer.play()
	
	_enemyBase = get_node_or_null("EnemyBase")
	_playerBase = get_node_or_null("Base")
	
	if _playerBase != null:
		_playerBase.base_state.connect(_on_player_base_destroy)
	
	_pauseScene = load("res://scenes/MenuScenes/PauseScreen.tscn")

func _on_player_base_destroy():
	if _enemyBase != null:
		_enemyBase.destroy()

func _on_TouchScreenButton_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/PauseScreen.tscn")
