extends CanvasLayer

@onready var sidebar = $Sidebar
@onready var dim_overlay = $DimOverlay

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_toggle_player_ui(false)

	# Анимация появления
	sidebar.position.x = -300
	dim_overlay.modulate.a = 0
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.tween_property(sidebar, "position:x", 0, 0.4).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_property(dim_overlay, "modulate:a", 1.0, 0.4)

func _on_ReturnToGameButton_pressed():
	# Анимация исчезновения
	var tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
	tween.tween_property(sidebar, "position:x", -300, 0.3).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN)
	tween.tween_property(dim_overlay, "modulate:a", 0.0, 0.3)

	await tween.finished
	get_tree().paused = false
	_toggle_player_ui(true)
	queue_free()

func _on_RestartButton_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_ReturnToSettingsButton_pressed():
	if GameManager != null:
		GameManager.set_meta("from_scene", get_tree().current_scene.scene_file_path)
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Settings.tscn")

func _on_LevelSelectorButton_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MenuScenes/LevelSelector.tscn")

func _on_ReturnToMenuButton_pressed():
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")

func _toggle_player_ui(is_visible: bool):
	# Рекурсивно скрываем все CanvasLayer, кроме этого экрана паузы
	_recursive_toggle_ui(get_tree().root, is_visible)

func _recursive_toggle_ui(node: Node, is_visible: bool):
	if node is CanvasLayer and node != self:
		node.visible = is_visible

	for child in node.get_children():
		_recursive_toggle_ui(child, is_visible)
