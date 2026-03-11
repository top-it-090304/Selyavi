extends Node2D
class_name Menu

func _on_Play_Button_pressed():
	get_tree().change_scene_to_file("res://scenes/Field.tscn")

func _on_Settings_Button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Settings.tscn")

func _on_Info_Button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Info.tscn")

func _on_Quit_Button_pressed():
	get_tree().quit()
