using Godot;
using System;

public partial class Bullet : Area2D
{
	#region private fields
	private int _bulletSpeed = 7;
	private Vector2 _velocity = Vector2.Zero;
	private AudioStreamPlayer _bulletSound;
	private Tween _tweenBullet;
	private VisibleOnScreenNotifier2D _visibilityBullet;
	private TypeBullet _typeBullet;
	private Sprite2D _bulletSprite;
	private int _damage;
	private bool _isPlayer;
	#endregion

	public int BulletSpeed
	{
		get => _bulletSpeed;
		set
		{
			if (value > 0 && value <= 30)
			{
				_bulletSpeed = value;
			}
		}
	}
	public bool IsPlayer{
		get => _isPlayer;
	}

	public override void _Ready()
	{
		_bulletSprite = GetNode<Sprite2D>("BulletSprite");
		_bulletSound = GetNode<AudioStreamPlayer>("PlasmaGunSound");
		_velocity = new Vector2(0, -1).Rotated(Rotation);
		_visibilityBullet = GetNode<VisibleOnScreenNotifier2D>("VisibleOnScreenNotifier2D");
		_tweenBullet = new Tween();
		AddChild(_tweenBullet);

		Connect("body_entered", new Callable(this, nameof(OnBodyEntered)));
		if (!_visibilityBullet.IsConnected("screen_exited", new Callable(this, nameof(onScreenExited))))
		{
			_visibilityBullet.Connect("screen_exited", new Callable(this, nameof(onScreenExited)));
		}
	}

	private void move()
	{
		Position += _velocity * _bulletSpeed;
	}

	private void fadeSound()
	{
		if (_tweenBullet == null) return;

		if (!_tweenBullet.IsInsideTree())
		{
			QueueFree();
			return;
		}

		if (_tweenBullet.IsConnected("tween_completed", new Callable(this, nameof(onTweenComplete))))
		{
			_tweenBullet.Disconnect("tween_completed", new Callable(this, nameof(onTweenComplete)));
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
		_tweenBullet.Connect("tween_completed", new Callable(this, nameof(onTweenComplete)));
	}

	private void onTweenComplete(Godot.Object obj, NodePath key)
	{
		_bulletSound.Stop();
		_bulletSound.VolumeDb = 0;
		QueueFree();
	}

	private void onScreenExited()
	{
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
		else if (body is IngameWall ingameWall)
		{
			if (ingameWall.can_bullet_pass())
			{
				return;
			}
			else if (ingameWall.destroyable())
			{
				ingameWall.destroy();
				Destroy();
			}
			
			else
			{
				Destroy();
			}
		}
		else if (body is Base baseObj)
		{
			Destroy();
		}
		else if (body is StaticBody2D staticWall)
		{
			Destroy();
		}
	}

	private void Destroy()
	{
		QueueFree();
	}

	private void UpdateType()
	{
		switch (_typeBullet)
		{
			case TypeBullet.Plasma:
				_bulletSprite.Texture2D = (Texture2D)GD.Load("res://assets/future_tanks/PNG/Effects/Plasma.png");
				_bulletSpeed = 7;
				_damage = 5;
				break;
			case TypeBullet.Medium:
				_bulletSprite.Texture2D = (Texture2D)GD.Load("res://assets/future_tanks/PNG/Effects/Medium_Shell.png");
				_bulletSpeed = 4;
				_damage = 10;
				break;
			case TypeBullet.Light3D:
				_bulletSprite.Texture2D = (Texture2D)GD.Load("res://assets/future_tanks/PNG/Effects/Light_Shell.png");
				_bulletSpeed = 6;
				_damage = 7;
				break;
		}

		if (AudioManager.Instance != null)
		{
			AudioManager.Instance.PlayBulletSound(_typeBullet, GlobalPosition);
		}
	}

	public void init(TypeBullet typeBullet, bool isPlayer)
	{
		_typeBullet = typeBullet;
		_isPlayer = isPlayer;
		UpdateType();
	}

	public override void _Process(float delta)
	{
		move();
	}
}
