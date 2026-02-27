using Godot;
using System;

public class PauseScreen : Node2D
{
		private void _on_ReturnToGameButton_pressed()
	{
		GetTree().ChangeScene("res://scenes/Field.tscn");
	}
	
	private void _on_ReturnToSettingsButton_pressed()
	{
		GetTree().ChangeScene("res://scenes/MenuScenes/Settings.tscn");
	}
	
	private void _on_ReturnToMenuButton_pressed()
	{
		GetTree().ChangeScene("res://scenes/MenuScenes/Menu.tscn");
	}
}
