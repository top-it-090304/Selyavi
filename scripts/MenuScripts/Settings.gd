extends Control

var _music_slider: Slider
var _sound_slider: Slider
var _scope_toggler: CheckButton
var _left_hand_toggler: CheckButton
var _music_label: Label
var _sound_label: Label
var _return_button: Button

func _ready():
	_music_slider = find_child("HSlider", true)
	_sound_slider = find_child("HSlider2", true)
	_scope_toggler = find_child("CheckButton", true)
	_left_hand_toggler = find_child("CheckButton_LeftHand", true)
	_music_label = find_child("MusicLabel", true)
	_sound_label = find_child("SfxLabel", true)
	_return_button = find_child("Return_Button", true)

	_load_ui_values()
	_update_return_button_text()

	if _sound_slider != null:
		_sound_slider.value_changed.connect(_on_sound_slider_changed)
	
	if _music_slider != null:
		_music_slider.value_changed.connect(_on_music_slider_changed)
	
	if _scope_toggler != null:
		# Соединяем сигнал переключения
		if not _scope_toggler.toggled.is_connected(_on_check_button_toggled):
			_scope_toggler.toggled.connect(_on_check_button_toggled)

	if _left_hand_toggler != null:
		if not _left_hand_toggler.toggled.is_connected(_on_left_hand_toggled):
			_left_hand_toggler.toggled.connect(_on_left_hand_toggled)

func _load_ui_values():
	if SaveManager == null: return

	if _sound_slider != null:
		var val = SaveManager.get_setting("audio", "sfx_volume", 1.0)
		_sound_slider.value = val

	if _music_slider != null:
		var val = SaveManager.get_setting("audio", "music_volume", 1.0)
		_music_slider.value = val

	if _scope_toggler != null:
		_scope_toggler.button_pressed = GameManager.is_scope_currently_enabled()

	if _left_hand_toggler != null:
		_left_hand_toggler.button_pressed = SaveManager.get_setting("controls", "lefty_mode", false)

func _update_return_button_text():
	if _return_button == null: return

	if GameManager.has_meta("from_scene"):
		var last_scene = GameManager.get_meta("from_scene")
		if not last_scene.contains("Menu.tscn"):
			_return_button.text = "ПРОДОЛЖИТЬ"
			return

	_return_button.text = "В МЕНЮ"

func _on_music_slider_changed(value: float):
	if SaveManager != null:
		SaveManager.set_setting("audio", "music_volume", value)
	if AudioManager != null:
		AudioManager.set_music_volume(value)

func _on_sound_slider_changed(value: float):
	if SaveManager != null:
		SaveManager.set_setting("audio", "sfx_volume", value)
	if AudioManager != null:
		AudioManager.set_sfx_volume(value)

func _on_check_button_toggled(button_pressed: bool):
	GameManager.set_scope_active(button_pressed)

func _on_left_hand_toggled(button_pressed: bool):
	if SaveManager != null:
		SaveManager.set_setting("controls", "lefty_mode", button_pressed)

func _on_Return_Button_pressed():
	if GameManager.has_meta("from_scene"):
		var last_scene = GameManager.get_meta("from_scene")
		GameManager.remove_meta("from_scene")
		get_tree().change_scene_to_file(last_scene)
	else:
		get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
