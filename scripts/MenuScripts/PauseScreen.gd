extends Node2D

func _ready():
	# Убеждаемся, что сцена паузы обрабатывается всегда
	process_mode = Node.PROCESS_MODE_ALWAYS

func _on_ReturnToGameButton_pressed():
	get_tree().paused = false
	queue_free()

func _on_ReturnToSettingsButton_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Settings.tscn")

func _on_ReturnToMenuButton_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
