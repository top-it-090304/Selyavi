using Godot;
using System;

public partial class PauseScreen : Node2D
{
		private void _on_ReturnToGameButton_pressed()
	{
		GetTree().ChangeSceneToFile("res://scenes/Field.tscn");
	}
	
	private void _on_ReturnToSettingsButton_pressed()
	{
		GetTree().ChangeSceneToFile("res://scenes/MenuScenes/Settings.tscn");
	}
	
	private void _on_ReturnToMenuButton_pressed()
	{
		GetTree().ChangeSceneToFile("res://scenes/MenuScenes/Menu.tscn");
	}
}
