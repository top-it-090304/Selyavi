using Godot;
using System;

public class Bullet : Area2D
{
	#region private fields
	private int _bulletSpeed = 7;
	private Vector2 _velocity = Vector2.Zero;
	// AudioStreamPlayer полностью удален
	private Tween _tweenBullet;
	private VisibilityNotifier2D _visibilityBullet;
	private TypeBullet _typeBullet;
	private Sprite _bulletSprite;
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
		_velocity = new Vector2(0, -1).Rotated(Rotation);
		_visibilityBullet = GetNode<VisibilityNotifier2D>("VisibilityNotifier2D");
		_tweenBullet = new Tween();
		
		if (!_visibilityBullet.IsConnected("screen_exited", this, nameof(onScreenExited)))
		{
			_visibilityBullet.Connect("screen_exited", this, nameof(onScreenExited));
		}
		AddChild(_tweenBullet);
		
		Connect("body_entered", this, nameof(OnBodyEntered));
	}
	
	private void move()
	{
		Position += _velocity * _bulletSpeed;
	}
	
	private void OnBodyEntered(Node body)
	{
		if (body is IngameWall wall)
		{
			if (wall.can_bullet_pass())
			{
				return;
			}
			else if (wall.destroyable())
			{
				wall.destroy();
				QueueFree();
			}
			else
			{
				QueueFree();
			}
		}
	}
	
	private void onScreenExited()
	{
		QueueFree();
	}
	
	private void UpdateType()
	{
		switch(_typeBullet)
		{
			case TypeBullet.Plasma:
				_bulletSprite.Texture = (Texture)GD.Load("res://assets/future_tanks/PNG/Effects/Plasma.png");
				_bulletSpeed = 7;
				break;
			case TypeBullet.Medium:
				_bulletSprite.Texture = (Texture)GD.Load("res://assets/future_tanks/PNG/Effects/Medium_Shell.png");
				_bulletSpeed = 4;
				break;
			case TypeBullet.Light:
				_bulletSprite.Texture = (Texture)GD.Load("res://assets/future_tanks/PNG/Effects/Light_Shell.png");
				_bulletSpeed = 5;
				break;
		}
		
		if (AudioManager.Instance != null)
		{
			AudioManager.Instance.PlayBulletSound(_typeBullet, GlobalPosition);
		}
	}
	
	public void init(TypeBullet typeBullet)
	{
		_typeBullet = typeBullet;
		UpdateType();
	}
	
	public override void _Process(float delta)
	{
		move();
	}
}
