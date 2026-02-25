using Godot;
using System;


public class Bullet : Area2D
{
	#region private fields
	private int _bulletSpeed = 7;
	private Vector2 _velocity = Vector2.Zero;
	private AudioStreamPlayer _bulletSound;
	private Tween _tweenBullet;
	private VisibilityNotifier2D _visibilityBullet;
	private TypeBullet _typeBullet;
	private Sprite _bulletSprite;
	private int _damage;
	private bool _isPlayer;
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
		_bulletSprite = GetNode<Sprite>("BulletSprite");
		_bulletSound = GetNode<AudioStreamPlayer>("PlasmaGunSound");
		_velocity = new Vector2(0, -1).Rotated(Rotation);
		_visibilityBullet = GetNode<VisibilityNotifier2D>("VisibilityNotifier2D");
		_tweenBullet = new Tween();
		Connect("body_entered", this, nameof(OnBodyEntered));
		if (!_visibilityBullet.IsConnected("screen_exited", this, nameof(onScreenExited)))
		{
			_visibilityBullet.Connect("screen_exited", this, nameof(onScreenExited));
		}
		AddChild(_tweenBullet);
		//_bulletSound.Play();
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
			_bulletSound,                    
			"volume_db",                   
			_bulletSound.VolumeDb,         
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
		_bulletSound.Stop();
		_bulletSound.VolumeDb = 0;
		QueueFree();
	}
	private void onScreenExited(){
		fadeSound();
	}
	
	private void OnBodyEntered(Node body)
	{
	
		if (body is Player player && !_isPlayer)
		{
			player.TakeDamage(_damage); 
			Destroy();
		}
		else if (body is Enemy enemy && _isPlayer)
		{
			enemy.TakeDamage(_damage);
			Destroy();
		}
		else if (body is StaticBody2D wall)
		{
			Destroy();
		}
	}
	
	private void Destroy()
	{
		QueueFree();
	}
	
	
	private void UpdateType(){
		switch(_typeBullet){
			case TypeBullet.Plasma:
				_bulletSprite.Texture = (Texture)GD.Load("res://assets/future_tanks/PNG/Effects/Plasma.png");
				_bulletSound.Stream = (AudioStream)GD.Load("res://assets/sounds/plasma_gun_06.mp3");
				_bulletSpeed = 7;
				_damage = 5;
				break;
			case TypeBullet.Medium:
				_bulletSprite.Texture = (Texture)GD.Load("res://assets/future_tanks/PNG/Effects/Medium_Shell.png");
				_bulletSound.Stream = (AudioStream)GD.Load("res://assets/sounds/vystrel-tanka.mp3");
				_bulletSpeed = 4;
				_damage = 10;
				break;
			case TypeBullet.Light:
				_bulletSprite.Texture = (Texture)GD.Load("res://assets/future_tanks/PNG/Effects/Light_Shell.png");
				_bulletSound.Stream = (AudioStream)GD.Load("res://assets/sounds/light_bullet.mp3");
				_bulletSpeed = 6;
				_damage = 7;
				break;
		}
		_bulletSound.Play();
	}
	public void init(TypeBullet typeBullet, bool isPlayer){
		_typeBullet = typeBullet;
		_isPlayer = isPlayer;
		UpdateType();
	}
  public override void _Process(float delta)
  {
	 move();
  }

}



