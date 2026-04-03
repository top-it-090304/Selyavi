extends CanvasLayer

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Прячем UI игрока при входе в паузу
	_toggle_player_ui(false)

func _on_ReturnToGameButton_pressed():
	get_tree().paused = false
	# Возвращаем UI игрока перед выходом
	_toggle_player_ui(true)
	queue_free()

func _on_RestartButton_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_ReturnToSettingsButton_pressed():
	# Сохраняем информацию, что мы перешли из игры
	if GameManager != null:
		GameManager.set_meta("from_scene", get_tree().current_scene.scene_file_path)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Settings.tscn")

func _on_ReturnToMenuButton_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")

func _toggle_player_ui(is_visible: bool):
	var tree = get_tree()
	# Скрываем все CanvasLayer в сцене, кроме текущего (экрана паузы)
	_recursive_toggle_ui(tree.root, is_visible)

func _recursive_toggle_ui(node: Node, is_visible: bool):
	if node is CanvasLayer and node != self:
		node.visible = is_visible

	for child in node.get_children():
		_recursive_toggle_ui(child, is_visible)
