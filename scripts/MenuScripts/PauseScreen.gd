extends CanvasLayer

func _ready():
	# Убеждаемся, что сцена паузы обрабатывается всегда
	process_mode = Node.PROCESS_MODE_ALWAYS

func _on_ReturnToGameButton_pressed():
	get_tree().paused = false
	queue_free()

func _on_RestartButton_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_ReturnToMenuButton_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
