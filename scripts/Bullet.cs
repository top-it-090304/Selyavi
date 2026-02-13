using Godot;
using System;

public class Bullet : Area2D
{
	#region private fields
	private int _bulletSpeed = 7;
	private Vector2 _velocity = Vector2.Zero;
	private AudioStreamPlayer _plasmaSound;
	private Tween _tweenBullet;
	private VisibilityNotifier2D _visibilityBullet;
	#endregion
	
	public int BulletSpeed{
		get => _bulletSpeed;
		set {
			if(value > 0 && value <= 30){
				_bulletSpeed = value;
			}
		}
	}
	
	

	public override void _Ready()
	{
		_plasmaSound = GetNode<AudioStreamPlayer>("PlasmaGunSound");
		_velocity = new Vector2(0, -1).Rotated(Rotation);
		_visibilityBullet = GetNode<VisibilityNotifier2D>("VisibilityNotifier2D");
		_tweenBullet = new Tween();
		if (!_visibilityBullet.IsConnected("screen_exited", this, nameof(onScreenExited)))
		{
			_visibilityBullet.Connect("screen_exited", this, nameof(onScreenExited));
		}
		AddChild(_tweenBullet);
		_plasmaSound.Play();
	}
	
	private void move(){
		
		Position += _velocity * _bulletSpeed;
		
	}
	private void fadeSound(){
		if (_tweenBullet.IsConnected("tween_completed", this, nameof(onTweenComplete)))
			{
				_tweenBullet.Disconnect("tween_completed", this, nameof(onTweenComplete));
			}
		_tweenBullet.InterpolateProperty(
			_plasmaSound,                    
			"volume_db",                   
			_plasmaSound.VolumeDb,         
			-80,                         
			1f,                          
			Tween.TransitionType.Linear,   
			Tween.EaseType.InOut          
		);
		_tweenBullet.Start();
		_tweenBullet.Connect("tween_completed", this, nameof(onTweenComplete));
	}
	private void onTweenComplete(Godot.Object obj, NodePath key)
	{
		_plasmaSound.Stop();
		_plasmaSound.VolumeDb = 0;
		QueueFree();
	}
	private void onScreenExited(){
		fadeSound();
	}

  public override void _Process(float delta)
  {
	 move();
  }



}





