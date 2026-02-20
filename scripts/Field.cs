using Godot;
using System;

public class Field : Node2D
{
	private AudioStreamPlayer _musicPlayer;

	public override void _Ready()
	{
		_musicPlayer = GetNodeOrNull<AudioStreamPlayer>("MusicPlayer");
		if (_musicPlayer != null)
		{
			_musicPlayer.Bus = "Music";
			_musicPlayer.Play();
		}
	}
	private void _on_Button_pressed()
	{
		GetTree().ChangeScene("res://scenes/MenuScenes/Settings.tscn");
	}

}
