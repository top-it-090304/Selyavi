extends Node2D
class_name PauseScreen

func _on_ReturnToGameButton_pressed():
	get_tree().change_scene_to_file("res://scenes/Field.tscn")

func _on_ReturnToSettingsButton_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Settings.tscn")

func _on_ReturnToMenuButton_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
