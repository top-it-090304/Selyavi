using Godot;
using System;

public class Menu : Node2D
{
	private void _on_Play_Button_pressed()
	{
		GetTree().ChangeScene("res://scenes/Field.tscn");
	}
	
	private void _on_Info_Button_pressed()
	{
		GetTree().ChangeScene("res://scenes/Info.tscn");
	}

	private void _on_Quit_Button_pressed()
	{	
		GetTree().Quit();
	}
}
