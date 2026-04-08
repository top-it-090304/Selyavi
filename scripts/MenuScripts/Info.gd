extends Control

func _ready():
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_menu()

func _on_Return_Button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
