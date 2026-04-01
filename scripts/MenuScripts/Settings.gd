extends Node2D

var _music_slider: Slider
var _sound_slider: Slider
var _scope_toggler: CheckButton

func _ready():
	_music_slider = get_node_or_null("HSlider")
	_sound_slider = get_node_or_null("HSlider2")
	_scope_toggler = get_node_or_null("CheckButton")
	
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
		_sound_slider.value = SaveManager.get_setting("audio", "sfx_volume", 1.0)

	if _music_slider != null:
		_music_slider.value = SaveManager.get_setting("audio", "music_volume", 1.0)

	if _scope_toggler != null:
		# Используем новую безопасную функцию из GameManager
		_scope_toggler.button_pressed = GameManager.is_scope_currently_enabled()

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
	# Вызываем новую безопасную функцию
	GameManager.set_scope_active(button_pressed)

func _on_Return_Button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
