using Godot;
using System;

public class Field : Node2D
{
	#region private fields
	private AudioStreamPlayer _musicPlayer;
	private PackedScene _pauseScene;
	private Node _currentPause;
	private Base _enemyBase;
	private Base _playerBase;
	#endregion
	
	public override void _Ready()
	{
		_musicPlayer = GetNodeOrNull<AudioStreamPlayer>("MusicPlayer");
		if (_musicPlayer != null)
		{
			_musicPlayer.Bus = "Music";
			_musicPlayer.Play();
		}
		
		_enemyBase = GetNode<Base>("EnemyBase");
		_playerBase = GetNode<Base>("Base");
		
		_playerBase.Connect("BaseState", this, nameof(PlayerBaseDestroy));
		
		_pauseScene = GD.Load<PackedScene>("res://scenes/MenuScenes/PauseScreen.tscn");
	}
	private void PlayerBaseDestroy(){
		_enemyBase.Destroy();
	}
	private void _on_TouchScreenButton_pressed()
	{
		GetTree().ChangeScene("res://scenes/MenuScenes/PauseScreen.tscn");
	}
}
