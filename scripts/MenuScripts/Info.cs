using Godot;
using System;

public class Info : Node2D
{
	private void _on_Return_Button_pressed()
	{
		GetTree().ChangeScene("res://scenes/MenuScenes/Menu.tscn");
	}
}
