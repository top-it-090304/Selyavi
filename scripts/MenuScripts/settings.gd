extends Node2D
class_name Settings

var _music_slider: Slider
var _sound_slider: Slider
var _scope_toggler: CheckButton

func _ready():
	_music_slider = get_node_or_null("HSlider")
	_sound_slider = get_node_or_null("HSlider2")
	_scope_toggler = get_node_or_null("CheckButton")
	
	_load_settings()
	
	if _sound_slider != null:
		_sound_slider.value_changed.connect(_on_sound_slider_changed)
	
	if _music_slider != null:
		_music_slider.value_changed.connect(_on_music_slider_changed)
	
	if _scope_toggler != null:
		if GameManager.instance != null:
			_scope_toggler.button_pressed = GameManager.instance._scope_enabled
		
		_scope_toggler.toggled.connect(_on_CheckButton_toggled)

func _on_music_slider_changed(value: float):
	AudioManager.instance.set_music_volume(value)
	_save_settings()

func _on_sound_slider_changed(value: float):
	AudioManager.instance.set_sfx_volume(value)
	_save_settings()

func _on_Return_Button_pressed():
	_save_settings()
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")

func _on_CheckButton_toggled(button_pressed: bool):
	if GameManager.instance != null:
		GameManager.instance._scope_enabled = button_pressed
	
	_save_settings()

func _load_settings():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		if _sound_slider != null:
			_sound_slider.value = config.get_value("audio", "sfx_volume", 1.0)
		
		if _music_slider != null:
			_music_slider.value = config.get_value("audio", "music_volume", 1.0)

func _save_settings():
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("audio", "sfx_volume", _sound_slider.value if _sound_slider != null else 1.0)
	config.set_value("audio", "music_volume", _music_slider.value if _music_slider != null else 1.0)
	config.set_value("game", "scope_enabled", _scope_toggler.button_pressed if _scope_toggler != null else true)
	config.save("user://settings.cfg")
