extends Node

var _target_scene_path: String = ""
var _loading_screen_scene = preload("res://scenes/MenuScenes/LoadingScreen.tscn")

func load_level(path: String):
	_target_scene_path = path
	# Сначала переходим на экран загрузки
	get_tree().change_scene_to_packed(_loading_screen_scene)

func get_target_path() -> String:
	return _target_scene_path
