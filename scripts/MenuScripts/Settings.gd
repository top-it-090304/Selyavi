extends Node2D

var _music_slider: Slider
var _sound_slider: Slider
var _scope_toggler: CheckButton
var _music_label: Label
var _sound_label: Label

func _ready():
	_music_slider = get_node_or_null("HSlider")
	_sound_slider = get_node_or_null("HSlider2")
	_scope_toggler = get_node_or_null("CheckButton")
	_music_label = get_node_or_null("Label")
	_sound_label = get_node_or_null("Label2")

	_load_ui_values()
	
	if _sound_slider != null:
		_sound_slider.value_changed.connect(_on_sound_slider_changed)
	
	if _music_slider != null:
		_music_slider.value_changed.connect(_on_music_slider_changed)
	
	if _scope_toggler != null:
		_scope_toggler.toggled.connect(_on_check_button_toggled)

func _load_ui_values():
	if SaveManager == null: return

	if _sound_slider != null:
		var val = SaveManager.get_setting("audio", "sfx_volume", 1.0)
		_sound_slider.value = val
		_update_sound_label(val)

	if _music_slider != null:
		var val = SaveManager.get_setting("audio", "music_volume", 1.0)
		_music_slider.value = val
		_update_music_label(val)

	if _scope_toggler != null:
		_scope_toggler.button_pressed = GameManager.is_scope_currently_enabled()

func _on_music_slider_changed(value: float):
	if SaveManager != null:
		SaveManager.set_setting("audio", "music_volume", value)
	if AudioManager != null:
		AudioManager.set_music_volume(value)
	_update_music_label(value)

func _on_sound_slider_changed(value: float):
	if SaveManager != null:
		SaveManager.set_setting("audio", "sfx_volume", value)
	if AudioManager != null:
		AudioManager.set_sfx_volume(value)
	_update_sound_label(value)

func _update_music_label(value: float):
	if _music_label != null:
		var db = linear_to_db(value)
		if value <= 0:
			_music_label.text = "Громкость музыки: MUTE"
		else:
			_music_label.text = "Громкость музыки: %.1f dB" % db

func _update_sound_label(value: float):
	if _sound_label != null:
		var db = linear_to_db(value)
		if value <= 0:
			_sound_label.text = "Громкость танка: MUTE"
		else:
			_sound_label.text = "Громкость танка: %.1f dB" % db

func _on_check_button_toggled(button_pressed: bool):
	GameManager.set_scope_active(button_pressed)

func _on_Return_Button_pressed():
	if GameManager.has_meta("from_scene"):
		var last_scene = GameManager.get_meta("from_scene")
		GameManager.remove_meta("from_scene")
		get_tree().change_scene_to_file(last_scene)
	else:
		get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
