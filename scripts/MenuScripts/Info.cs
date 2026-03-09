using Godot;
using System;

public partial class Info : Node2D
{
	private void _on_Return_Button_pressed()
	{
		GetTree().ChangeSceneToFile("res://scenes/MenuScenes/Menu.tscn");
	}
}
