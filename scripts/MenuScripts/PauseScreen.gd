extends Node2D

func _on_ReturnToGameButton_pressed():
	get_tree().change_scene("res://scenes/Field.tscn")

func _on_ReturnToSettingsButton_pressed():
	get_tree().change_scene("res://scenes/MenuScenes/Settings.tscn")

func _on_ReturnToMenuButton_pressed():
	get_tree().change_scene("res://scenes/MenuScenes/Menu.tscn")
