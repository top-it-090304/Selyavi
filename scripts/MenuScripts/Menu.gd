extends Node2D

func _on_Play_Button_pressed():
	get_tree().change_scene("res://scenes/Field.tscn")

func _on_Settings_Button_pressed():
	get_tree().change_scene("res://scenes/MenuScenes/Settings.tscn")

func _on_Info_Button_pressed():
	get_tree().change_scene("res://scenes/MenuScenes/Info.tscn")

func _on_Quit_Button_pressed():
	get_tree().quit()
