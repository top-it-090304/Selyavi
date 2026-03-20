using Godot;
using System;

public abstract class Tank : KinematicBody2D
{
	#region protected fields
	protected int _speed = 250;
	protected int _hp;
	protected bool _isMoving = false;
	protected Vector2 _velocity = Vector2.Zero;
	protected Position2D _bulletPosition;
	protected Timer _shootTimer;
	protected Sprite _gun;
	protected Tween _tween;
	protected AudioStreamPlayer _movingSound;
	protected float _normalMovementVolume = 0f;
	#endregion
	protected PackedScene bulletScene;

	public override void _Ready()
	{
		_shootTimer = new Timer();
		_shootTimer.WaitTime = 1f;
		_shootTimer.OneShot = true;
		AddChild(_shootTimer);

		_tween = new Tween();
		AddChild(_tween);

		_bulletPosition = GetNode<Position2D>("BodyTank/Gun/BulletPosition");
		_gun = GetNode<Sprite>("BodyTank/Gun");
		_movingSound = GetNode<AudioStreamPlayer>("MovingSound");
		
		ConfigureAudio();
		if (_movingSound != null)
		{
			_normalMovementVolume = _movingSound.VolumeDb;
		}
	}

	protected virtual void ConfigureAudio()
	{
		if (_movingSound != null)
		{
			_movingSound.Bus = "SFX";
		}
	}

	protected void HandleMovementSound(Vector2 movementVelocity)
	{
		bool isMovingNow = movementVelocity.Length() > 0.1f;

		if (isMovingNow)
		{
			if (!_isMoving)
			{
				if (_tween.IsActive())
				{
					_tween.StopAll();
					_tween.RemoveAll();
				}
				if (_movingSound != null)
				{
					_movingSound.VolumeDb = _normalMovementVolume;
					if (!_movingSound.Playing)
					{
						_movingSound.Play();
					}
				}
				_isMoving = true;
			}
		}
		else
		{
			if (_isMoving)
			{
				_isMoving = false;

				if (_movingSound != null && _movingSound.Playing)
				{
					FadeSound();
				}
			}
		}
	}

	protected void FadeSound()
	{
		if (_tween.IsConnected("tween_completed", this, nameof(OnTweenComplete)))
		{
			_tween.Disconnect("tween_completed", this, nameof(OnTweenComplete));
		}
		if (_tween.IsActive())
		{
			_tween.StopAll();
			_tween.RemoveAll();
		}
		_tween.InterpolateProperty(
			_movingSound,
			"volume_db",
			_movingSound.VolumeDb,
			-80,
			0.3f,
			Tween.TransitionType.Linear,
			Tween.EaseType.InOut
		);
		_tween.Start();
		_tween.Connect("tween_completed", this, nameof(OnTweenComplete));
	}

	private void OnTweenComplete(Godot.Object obj, NodePath key)
	{
		_movingSound.Stop();
		_movingSound.VolumeDb = _normalMovementVolume;
	}

	protected virtual void RotateGunToward(Vector2 targetGlobalPosition)
	{
		if (_gun == null) return;

		Vector2 directionToTarget = (targetGlobalPosition - _gun.GlobalPosition).Normalized();
		float targetAngle = directionToTarget.Angle();
		_gun.GlobalRotation = targetAngle + Mathf.Pi / 2;
	}

	protected virtual void FireBullet(TypeBullet type, bool isPlayer)
	{
		if (_shootTimer.TimeLeft > 0) return;

		var bullet = (Bullet)bulletScene.Instance();
		bullet.GlobalPosition = _bulletPosition.GlobalPosition;
		bullet.GlobalRotation = _gun.GlobalRotation;
		GetTree().Root.AddChild(bullet);
		bullet.init(type, isPlayer);
		_shootTimer.Start();
	}

	public void TakeDamage(int damage)
	{
		_hp -= damage;
		if (_hp <= 0)
		{
			Destroy();
		}
	}

	protected virtual void Destroy()
	{
		QueueFree();
	}
}
