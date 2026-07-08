extends Control

func _ready():
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_menu()

func _on_Play_Button_pressed():
	_show_play_submenu()

func _go_to_missions():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/LevelSelector.tscn")

func _go_to_endless_mode():
	var path = "res://scenes/EndlessMode.tscn"
	if has_node("/root/LoadingManager"):
		get_node("/root/LoadingManager").load_level(path)
	else:
		get_tree().change_scene_to_file(path)

func _show_play_submenu():
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	canvas.add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center_container = CenterContainer.new()
	canvas.add_child(center_container)
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel = PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center_container.add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.180392, 0.219608, 0.180392, 1)
	style.set_border_width_all(4)
	style.border_color = Color(0.290196, 0.341176, 0.25098, 1)
	style.set_corner_radius_all(20)
	panel.add_theme_stylebox_override("panel", style)

	var margin = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30); margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_top", 30); margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 20); margin.add_child(vbox)

	var font = load("res://assets/fonts/ofont.ru_Shonen.ttf")

	var title = Label.new()
	title.text = "ВЫБЕРИТЕ РЕЖИМ"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_font_override("font", font)
	vbox.add_child(title)

	var btn_container = VBoxContainer.new(); btn_container.add_theme_constant_override("separation", 12); vbox.add_child(btn_container)

	var style_btn = func(btn: Button):
		btn.custom_minimum_size = Vector2(0, 70)
		btn.focus_mode = Control.FOCUS_NONE
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.180392, 0.219608, 0.180392, 1)
		btn_style.set_border_width_all(2); btn_style.border_width_bottom = 6
		btn_style.border_color = Color(0.290196, 0.341176, 0.25098, 1)
		btn_style.set_corner_radius_all(12)
		btn.add_theme_stylebox_override("normal", btn_style)
		btn.add_theme_font_size_override("font_size", 28)
		btn.add_theme_font_override("font", font)

	var btn_endless = Button.new(); btn_endless.text = "БЕСКОНЕЧНЫЙ РЕЖИМ"; style_btn.call(btn_endless); btn_container.add_child(btn_endless)
	btn_endless.pressed.connect(_go_to_endless_mode)

	var btn_missions = Button.new(); btn_missions.text = "МИССИИ"; style_btn.call(btn_missions); btn_container.add_child(btn_missions)
	btn_missions.pressed.connect(_go_to_missions)

	var btn_back = Button.new(); btn_back.text = "НАЗАД"; style_btn.call(btn_back); btn_container.add_child(btn_back)
	btn_back.pressed.connect(func(): canvas.queue_free())

func _on_Shop_Button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Shop.tscn")

func _on_Achievements_Button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Achievements.tscn")

func _on_Settings_Button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Settings.tscn")

func _on_Info_Button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Info.tscn")

func _on_Quit_Button_pressed():
	await PycoLog.log_stop_playing()
	get_tree().quit()
