using Godot;
using System;

public class PlayerTank : Tank
{
	#region private fields
	private int _lives;
	private bool _isScopeEnadled = true;
	private CanvasLayer _joystick;
	private MobileJoystick _aim;
	private TypeBullet _typeBullet = TypeBullet.Plasma;
	private Vector2 _startPosition;
	#endregion

	public int Speed
	{
		get => _speed;
		set
		{
			if (value > 0 && value <= 800)
			{
				_speed = value;
			}
		}
	}

	public override void _Ready()
	{
		base._Ready();
		Init();
		
		if (AudioManager.Instance != null)
		{
			AudioManager.Instance.Connect(nameof(AudioManager.SfxVolumeChanged), this, nameof(OnSfxVolumeChanged));
		}

		if (GameManager.Instance != null)
		{
			GameManager.Instance.Connect(nameof(GameManager.ScopeToggled), this, nameof(ToggleScope));
			_isScopeEnadled = GameManager.Instance.ScopeEnabled;
		}
		else
		{
			LoadInitialScopeState();
		}
	}

	private void OnSfxVolumeChanged(float value)
	{
		float dbValue = GD.Linear2Db(value);
		_normalMovementVolume = dbValue;
		if (_movingSound.Playing)
		{
			_movingSound.VolumeDb = dbValue;
		}
	}

	private void LoadInitialScopeState()
	{
		var config = new ConfigFile();
		if (config.Load("user://settings.cfg") == Error.Ok)
		{
			_isScopeEnadled = (bool)config.GetValue("game", "scope_enabled", true);
		}
		else
		{
			_isScopeEnadled = true;
		}
	}

	private void ToggleScope(bool checkboxValue)
	{
		_isScopeEnadled = checkboxValue;
		Update();
	}

	private void useMoveVector(Vector2 moveVector)
	{
		Vector2 joystickVelocity = moveVector * 200;
		MoveAndSlide(joystickVelocity);
		RotatePlayerMobile(moveVector);
		HandleMovementSound(joystickVelocity);
	}

	private void FireTouch()
	{
		FireBullet(_typeBullet, true);
	}

	private void useMoveVectorAim(Vector2 moveVector)
	{
		RotatePlayerMobileAim(moveVector);
	}

	public override void _PhysicsProcess(float delta)
	{
		GetInput();
		_velocity = MoveAndSlide(_velocity);
	}

	private void GetInput()
	{
		Move();
		ChangeBullet();
	}

	private void ChangeBullet()
	{
		bool bulletChanged = false;
		if (Input.IsActionJustPressed("plasma"))
		{
			_typeBullet = TypeBullet.Plasma;
			bulletChanged = true;
		}
		else if (Input.IsActionJustPressed("medium_bullet"))
		{
			_typeBullet = TypeBullet.Medium;
			bulletChanged = true;
		}
		else if (Input.IsActionJustPressed("light_bullet"))
		{
			_typeBullet = TypeBullet.Light;
			bulletChanged = true;
		}

		if (bulletChanged)
		{
			_shootTimer.Start();
		}
	}

	private void Move()
	{
		_velocity.x = Input.GetActionStrength("move_right") - Input.GetActionStrength("move_left");
		_velocity.y = Input.GetActionStrength("move_down") - Input.GetActionStrength("move_up");

		if (_velocity.Length() > 0)
		{
			_velocity = _velocity.Normalized() * _speed;
			RotatePlayer(_velocity);
			HandleMovementSound(_velocity);
		}
		else
		{
			HandleMovementSound(Vector2.Zero);
		}
	}

	private void RotatePlayerMobile(Vector2 direction)
	{
		RotationDegrees = Mathf.Rad2Deg(direction.Angle()) + 90;
	}

	private void RotatePlayerMobileAim(Vector2 direction)
	{
		RotateGunToward(_gun.GlobalPosition + direction * 100);
	}

	private void RotatePlayer(Vector2 direction)
	{
		if (direction.x > 0)
		{
			if (direction.y < 0) RotationDegrees = 45;
			else if (direction.y > 0) RotationDegrees = 90 + 45;
			else RotationDegrees = 90;
		}
		else if (direction.x < 0)
		{
			if (direction.y < 0) RotationDegrees = 270 + 45;
			else if (direction.y > 0) RotationDegrees = 270 - 45;
			else RotationDegrees = 270;
		}
		else if (direction.y > 0) RotationDegrees = 180;
		else if (direction.y < 0) RotationDegrees = 0;
	}

	private void fire()
	{
		if (Input.IsActionJustPressed("fire"))
		{
			FireTouch();
		}
	}

	protected override void Destroy()
	{
		_lives--;
		if (_lives != 0)
			Revive();
		else
			base.Destroy();
	}

	private void Revive()
	{
		_hp = 20;
		GlobalPosition = _startPosition;
	}

	public override void _Draw()
	{
		if (_aim.IsJoystickActive && _isScopeEnadled)
		{
			Vector2 globalMuzzlePos = _bulletPosition.GlobalPosition;
			float gunAngle = _gun.GlobalRotation;
			Vector2 direction = new Vector2(1, 0).Rotated(gunAngle);
			Vector2 perpendicular = new Vector2(direction.y, -direction.x);
			float rayLength = 1000f;
			Vector2 globalRayEnd = globalMuzzlePos + perpendicular * rayLength;
			Vector2 localMuzzlePos = ToLocal(globalMuzzlePos);
			Vector2 localRayEnd = ToLocal(globalRayEnd);
			DrawLine(localMuzzlePos, localRayEnd, Colors.Red, 2f);
		}
	}

	private void Init()
	{
		_lives = 5;
		_hp = 20;
		_joystick = GetNode<CanvasLayer>("Joystick");
		_aim = GetNode<MobileJoystick>("Aim");
		_startPosition = GlobalPosition;
		_aim.init(true);

		if (_aim != null)
		{
			_aim.Connect("UseMoveVector", this, nameof(useMoveVectorAim));
			_aim.Connect("FireTouch", this, nameof(FireTouch));
		}
		_joystick.Connect("UseMoveVector", this, nameof(useMoveVector));
		
		bulletScene = (PackedScene)GD.Load("res://scenes/Tank/Bullet.tscn");
	}
}
