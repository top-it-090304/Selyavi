using Godot;
using System;

public class Field : Node2D
{
	private AudioStreamPlayer _musicPlayer;
	//private AudioStreamPlayer _soundPlayer;
	public override void _Ready()
	{
		_musicPlayer = GetNodeOrNull<AudioStreamPlayer>("MusicPlayer");
		//_soundPlayer = GetNodeOrNull<AudioStreamPlayer>("SoundPlayer");
		if (_musicPlayer != null)
		{
			//_soundPlayer.Bus = "SFX";
			_musicPlayer.Bus = "Music";
			_musicPlayer.Play();
		}
	}
	private void _on_TouchScreenButton_pressed()
	{
		GetTree().ChangeScene("res://scenes/MenuScenes/PauseScreen.tscn");
	}
}
