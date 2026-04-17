extends Control

@onready var game_settings = find_child("GameSettings", true)
@onready var audio_settings = find_child("AudioSettings", true)
@onready var game_tab_btn = find_child("GameTab", true)
@onready var audio_tab_btn = find_child("AudioTab", true)
@onready var reset_dialog = get_node("ResetConfirmation")

var _music_slider: Slider
var _sound_slider: Slider
var _scope_toggler: CheckButton
var _aim_assist_toggler: CheckButton
var _left_hand_toggler: CheckButton
var _fov_slider: HSlider
var _marker_slider: HSlider
var _return_button: Button
var _reset_progress_btn: Button

var _sfx_preview_timer: Timer

func _ready():
	_music_slider = audio_settings.find_child("HSlider", true)
	_sound_slider = audio_settings.find_child("HSlider2", true)

	_scope_toggler = game_settings.find_child("CheckButton", true)
	_aim_assist_toggler = game_settings.find_child("CheckButton_AimAssist", true)
	_left_hand_toggler = game_settings.find_child("CheckButton_LeftHand", true)
	_fov_slider = game_settings.find_child("HSlider_CameraFov", true)
	_marker_slider = game_settings.find_child("HSlider_MarkerScale", true)
	_reset_progress_btn = game_settings.find_child("ResetProgressBtn", true)

	_return_button = find_child("Return_Button", true)

	_load_ui_values()
	_update_return_button_text()
	_setup_sfx_preview()
	_apply_tab_styles()
	_setup_reset_dialog_style()
	_check_reset_button_visibility()

	# Коннекты
	if _sound_slider:
		_sound_slider.value_changed.connect(_on_sound_slider_changed)
		_sound_slider.drag_started.connect(_on_sfx_drag_started)
		_sound_slider.drag_ended.connect(_on_sfx_drag_ended)

	if _music_slider: _music_slider.value_changed.connect(_on_music_slider_changed)
	if _scope_toggler: _scope_toggler.toggled.connect(_on_check_button_toggled)
	if _aim_assist_toggler: _aim_assist_toggler.toggled.connect(_on_aim_assist_toggled)
	if _left_hand_toggler: _left_hand_toggler.toggled.connect(_on_left_hand_toggled)
	if _fov_slider: _fov_slider.value_changed.connect(_on_fov_slider_changed)
	if _marker_slider: _marker_slider.value_changed.connect(_on_marker_scale_changed)

func _check_reset_button_visibility():
	if _reset_progress_btn == null: return

	var game_mgr = get_node_or_null("/root/GameManager")
	var is_from_menu = true # По умолчанию считаем, что мы в меню

	if game_mgr and game_mgr.has_meta("from_scene"):
		var last_scene = game_mgr.get_meta("from_scene")
		# Если мы пришли из миссии (не из меню), скрываем кнопку
		if not last_scene.contains("Menu.tscn"):
			is_from_menu = false

	_reset_progress_btn.visible = is_from_menu

func _setup_reset_dialog_style():
	if not reset_dialog: return

	var main_font = load("res://assets/fonts/ofont.ru_Shonen.ttf")

	# Текст сообщения
	var label = reset_dialog.get_label()
	if label:
		label.add_theme_font_override("font", main_font)
		label.add_theme_font_size_override("font_size", 36)
		label.add_theme_constant_override("line_spacing", 12)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(700, 200)

	# Кнопка ОК (ДА, СБРОСИТЬ)
	var ok_btn = reset_dialog.get_ok_button()
	if ok_btn:
		ok_btn.add_theme_font_override("font", main_font)
		ok_btn.add_theme_font_size_override("font_size", 32)
		ok_btn.custom_minimum_size = Vector2(380, 130)

		var red_normal = StyleBoxFlat.new()
		red_normal.bg_color = Color(0.55, 0.11, 0.11)
		red_normal.set_corner_radius_all(15)
		red_normal.border_width_bottom = 10
		red_normal.border_color = Color(0.35, 0.05, 0.05)
		red_normal.content_margin_left = 30
		red_normal.content_margin_right = 30
		red_normal.content_margin_top = 20
		red_normal.content_margin_bottom = 20

		var red_hover = red_normal.duplicate()
		red_hover.bg_color = Color(0.7, 0.12, 0.12)
		red_hover.border_color = Color(0.5, 0.1, 0.1)

		var red_pressed = red_normal.duplicate()
		red_pressed.bg_color = Color(0.4, 0.08, 0.08)
		red_pressed.border_width_top = 8
		red_pressed.border_width_bottom = 2
		red_pressed.content_margin_top = 28

		ok_btn.add_theme_stylebox_override("normal", red_normal)
		ok_btn.add_theme_stylebox_override("hover", red_hover)
		ok_btn.add_theme_stylebox_override("pressed", red_pressed)
		ok_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	# Кнопка ОТМЕНА
	var cancel_btn = reset_dialog.get_cancel_button()
	if cancel_btn:
		cancel_btn.add_theme_font_override("font", main_font)
		cancel_btn.add_theme_font_size_override("font_size", 32)
		cancel_btn.custom_minimum_size = Vector2(300, 130)

		var grey_style = StyleBoxFlat.new()
		grey_style.bg_color = Color(0.18, 0.22, 0.18)
		grey_style.set_corner_radius_all(15)
		grey_style.border_width_bottom = 10
		grey_style.border_color = Color(0.08, 0.1, 0.08)
		grey_style.content_margin_left = 35
		grey_style.content_margin_right = 35
		grey_style.content_margin_top = 20
		grey_style.content_margin_bottom = 20

		var grey_hover = grey_style.duplicate()
		grey_hover.bg_color = Color(0.25, 0.3, 0.25)

		cancel_btn.add_theme_stylebox_override("normal", grey_style)
		cancel_btn.add_theme_stylebox_override("hover", grey_hover)
		cancel_btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

func _on_reset_btn_pressed():
	if reset_dialog:
		reset_dialog.popup_centered()

func _on_reset_progress_confirmed():
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr and save_mgr.has_method("reset_progress"):
		save_mgr.reset_progress()
		get_tree().reload_current_scene()

func _on_tab_pressed(tab_name: String):
	game_settings.visible = (tab_name == "game")
	audio_settings.visible = (tab_name == "audio")
	_apply_tab_styles()

func _apply_tab_styles():
	game_tab_btn.modulate = Color(1, 1, 1, 1) if game_settings.visible else Color(0.6, 0.6, 0.6, 1)
	audio_tab_btn.modulate = Color(1, 1, 1, 1) if audio_settings.visible else Color(0.6, 0.6, 0.6, 1)

func _load_ui_values():
	var save_mgr = get_node_or_null("/root/SaveManager")
	var game_mgr = get_node_or_null("/root/GameManager")

	if save_mgr:
		if _sound_slider: _sound_slider.value = save_mgr.get_setting("audio", "sfx_volume", 1.0)
		if _music_slider: _music_slider.value = save_mgr.get_setting("audio", "music_volume", 1.0)
		if _aim_assist_toggler: _aim_assist_toggler.button_pressed = save_mgr.get_setting("game", "aim_assist", true)
		if _left_hand_toggler: _left_hand_toggler.button_pressed = save_mgr.get_setting("game", "lefty_mode", false)
		if _fov_slider: _fov_slider.value = float(save_mgr.get_setting("game", "camera_fov", 50.0))
		if _marker_slider: _marker_slider.value = float(save_mgr.get_setting("game", "marker_scale", 1.0))

	if game_mgr and _scope_toggler:
		_scope_toggler.button_pressed = game_mgr.is_scope_currently_enabled()

func _on_marker_scale_changed(value: float):
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr: save_mgr.set_setting("game", "marker_scale", value)

func _on_fov_slider_changed(value: float):
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr: save_mgr.set_setting("game", "camera_fov", value)

func _on_music_slider_changed(value: float):
	var save_mgr = get_node_or_null("/root/SaveManager")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if save_mgr: save_mgr.set_setting("audio", "music_volume", value)
	if audio_mgr: audio_mgr.set_music_volume(value)

func _on_sound_slider_changed(value: float):
	var save_mgr = get_node_or_null("/root/SaveManager")
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if save_mgr: save_mgr.set_setting("audio", "sfx_volume", value)
	if audio_mgr: audio_mgr.set_sfx_volume(value)

func _on_check_button_toggled(button_pressed: bool):
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr: game_mgr.set_scope_active(button_pressed)

func _on_aim_assist_toggled(button_pressed: bool):
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr: save_mgr.set_setting("game", "aim_assist", button_pressed)

func _on_left_hand_toggled(button_pressed: bool):
	var save_mgr = get_node_or_null("/root/SaveManager")
	if save_mgr: save_mgr.set_setting("game", "lefty_mode", button_pressed)

func _update_return_button_text():
	if _return_button == null: return
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_meta("from_scene"):
		var last_scene = game_mgr.get_meta("from_scene")
		if not last_scene.contains("Menu.tscn"):
			_return_button.text = "ПРОДОЛЖИТЬ"; return
	_return_button.text = "В МЕНЮ"

func _on_Return_Button_pressed():
	var game_mgr = get_node_or_null("/root/GameManager")
	if game_mgr and game_mgr.has_meta("from_scene"):
		var last_scene = game_mgr.get_meta("from_scene")
		game_mgr.remove_meta("from_scene")
		get_tree().change_scene_to_file(last_scene)
	else:
		get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")

# region SFX Preview
func _setup_sfx_preview():
	_sfx_preview_timer = Timer.new()
	_sfx_preview_timer.wait_time = 1.0
	_sfx_preview_timer.timeout.connect(_play_preview_sound)
	add_child(_sfx_preview_timer)

func _play_preview_sound():
	var audio_mgr = get_node_or_null("/root/AudioManager")
	if audio_mgr: audio_mgr.play_bullet_sound(1)

func _on_sfx_drag_started():
	_play_preview_sound()
	_sfx_preview_timer.start()

func _on_sfx_drag_ended(_value_changed: bool):
	_sfx_preview_timer.stop()
# endregion
