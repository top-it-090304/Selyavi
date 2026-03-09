using Godot;
using System;

public partial class Menu : Node2D
{
	private void _on_Play_Button_pressed()
	{
		GetTree().ChangeSceneToFile("res://scenes/Field.tscn");
	}
	
	private void _on_Settings_Button_pressed()
	{
		GetTree().ChangeSceneToFile("res://scenes/MenuScenes/Settings.tscn");
	}

	private void _on_Info_Button_pressed()
	{
		GetTree().ChangeSceneToFile("res://scenes/MenuScenes/Info.tscn");
	}

	private void _on_Quit_Button_pressed()
	{	
		GetTree().Quit();
	}
}
