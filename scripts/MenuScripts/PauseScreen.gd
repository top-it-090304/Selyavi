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
	_show_confirm_dialog("ПЕРЕЗАГРУЗИТЬ УРОВЕНЬ?", "Весь текущий прогресс будет утерян!", func():
		get_tree().paused = false
		var current_scene_path = get_tree().current_scene.scene_file_path
		if has_node("/root/LoadingManager"):
			get_node("/root/LoadingManager").load_level(current_scene_path)
		else:
			get_tree().reload_current_scene()
	)

func _on_ReturnToSettingsButton_pressed():
	_show_confirm_dialog("ВЫЙТИ В НАСТРОЙКИ?", "Прогресс миссии будет утерян!", func():
		if GameManager != null:
			GameManager.set_meta("from_scene", get_tree().current_scene.scene_file_path)
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/MenuScenes/Settings.tscn")
	)

func _on_LevelSelectorButton_pressed():
	_show_confirm_dialog("ВЫБОР МИССИИ?", "Вы покинете текущий бой.", func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/MenuScenes/LevelSelector.tscn")
	)

func _on_ReturnToMenuButton_pressed():
	_show_confirm_dialog("В ГЛАВНОЕ МЕНЮ?", "Прогресс миссии будет утерян!", func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
	)

func _show_confirm_dialog(title_text: String, desc_text: String, on_confirm: Callable):
	# Создаем оверлей
	var dialog_overlay = ColorRect.new()
	dialog_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog_overlay.color = Color(0, 0, 0, 0.6)
	add_child(dialog_overlay)

	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog_overlay.add_child(center)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(750, 450) # Значительно увеличено окно
	center.add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.13, 0.12, 0.98)
	style.border_width_left = 6; style.border_width_top = 6; style.border_width_right = 6; style.border_width_bottom = 6
	style.border_color = Color(0.8, 0.2, 0.2) # Акцент на предупреждении
	style.set_corner_radius_all(25)
	style.shadow_size = 40
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40); margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 40); margin.add_theme_constant_override("margin_bottom", 40)
	panel.add_child(margin)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 40)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	var title = Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	vbox.add_child(title)

	var desc = Label.new()
	desc.text = desc_text
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(650, 0)
	desc.add_theme_font_size_override("font_size", 36)
	vbox.add_child(desc)

	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 60)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(hbox)

	var btn_style = func(btn: Button, is_danger: bool):
		btn.custom_minimum_size = Vector2(260, 100)
		btn.add_theme_font_size_override("font_size", 38)
		var b_style = StyleBoxFlat.new()
		b_style.bg_color = Color(0.4, 0.1, 0.1) if is_danger else Color(0.25, 0.25, 0.25)
		b_style.set_corner_radius_all(15)
		b_style.border_width_bottom = 10
		b_style.border_color = Color(0.2, 0.05, 0.05) if is_danger else Color(0.15, 0.15, 0.15)
		btn.add_theme_stylebox_override("normal", b_style)

		var h_style = b_style.duplicate()
		h_style.bg_color = h_style.bg_color.lightened(0.1)
		btn.add_theme_stylebox_override("hover", h_style)

	var btn_yes = Button.new()
	btn_yes.text = "ДА"
	btn_style.call(btn_yes, true)
	hbox.add_child(btn_yes)
	btn_yes.pressed.connect(on_confirm)

	var btn_no = Button.new()
	btn_no.text = "НЕТ"
	btn_style.call(btn_no, false)
	hbox.add_child(btn_no)
	btn_no.pressed.connect(func(): dialog_overlay.queue_free())

func _toggle_player_ui(is_visible: bool):
	_recursive_toggle_ui(get_tree().root, is_visible)

func _recursive_toggle_ui(node: Node, is_visible: bool):
	if node is CanvasLayer and node != self:
		node.visible = is_visible

	for child in node.get_children():
		_recursive_toggle_ui(child, is_visible)
