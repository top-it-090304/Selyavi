extends Control

func _ready():
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_menu()

func _on_Play_Button_pressed():
	# Переход в выбор уровней
	get_tree().change_scene_to_file("res://scenes/MenuScenes/LevelSelector.tscn")

func _on_Shop_Button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Shop.tscn")

func _on_Settings_Button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Settings.tscn")

func _on_Info_Button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Info.tscn")

func _on_Quit_Button_pressed():
	get_tree().quit()
