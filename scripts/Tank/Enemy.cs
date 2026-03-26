using Godot;
using System;

public class Enemy : KinematicBody2D
{
	private enum State { PATROL, CHASE }
	
	#region private fields
	private State _currentState;
	private Area2D _detectionArea;
	private int _hp = 10;
	private Player _player;
	private Base _base;
	[Export] private int _patrolSpeed = 90;
	[Export] private int _chaseSpeed = 100;
	private Vector2 _velocity = Vector2.Zero;
	private Position2D _bulletPosition;
	private Timer _shootTimer;
	private Sprite _gun;
	private Sprite _body;
	private int _damage = 20;
	private NavigationAgent2D _nav2d;
	private RayCast2D _rayCast;
	private TypeEnemy _typeEnemy;
	private AudioStreamPlayer _movingSound;
	private Tween _tween;
	private bool _isMoving = false;
	private float _normalMovementVolume = -20f;
	#endregion
	PackedScene bulletScene;
	private enum TypeEnemy{
		Light,
		Medium,
		Heavy
	}

	public override void _Ready()
	{
		init();
		AddChild(_shootTimer);
		AddChild(_tween);
		
		if (_nav2d != null)
		{
			_nav2d.MaxSpeed = _patrolSpeed;
			_nav2d.TargetDesiredDistance = 10f;
			_nav2d.PathDesiredDistance = 5f;
		}
		
		ConfigureAudioPlayers();
		if (_movingSound != null)
		{
			_normalMovementVolume = _movingSound.VolumeDb;
		}
	}

	private void ConfigureAudioPlayers()
	{
		int sfxBusIndex = AudioServer.GetBusIndex("SFX");
		
		if (_movingSound != null)
		{
			_movingSound.Bus = "SFX";
		}
	}

	public override void _PhysicsProcess(float delta)
	{
		if (!Godot.Object.IsInstanceValid(_base))
		{
			Destroy();
			return;
		}
		
		UpdateTarget();
		AimGun();
		UpdateRayCast();
		CheckAndFire();
		MoveEnemy();
		_velocity = MoveAndSlide(_velocity);
	}

	private void HandleMovementSound(Vector2 movementVelocity)
	{
		bool isMovingNow = movementVelocity.Length() > 0.1f;
		
		if (isMovingNow)
		{
			if(!_isMoving)
			{
				if(_tween.IsActive())
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
			if(_isMoving)
			{
				_isMoving = false;
				
				if (_movingSound != null && _movingSound.Playing)
				{
					fadeSound();
				}
			}
		}
	}
	
	private void UpdateTarget()
	{
		if (_nav2d == null) return;
		
		switch (_currentState)
		{
			case State.PATROL:
				if (_base != null && Godot.Object.IsInstanceValid(_base))
				{
					_nav2d.TargetLocation = _base.GlobalPosition;
				}
				else
				{
					Destroy();
				}
				break;
				
			case State.CHASE:
				if (_player != null && Godot.Object.IsInstanceValid(_player))
				{
					_nav2d.TargetLocation = _player.GlobalPosition;
				}
				break;
		}
	}
	
	private void AimGun()
	{
		if (_gun == null) return;
		
		Node2D target = GetCurrentTarget();
		if (target == null || !Godot.Object.IsInstanceValid(target)) return;
		
		Vector2 directionToTarget = (target.GlobalPosition - _gun.GlobalPosition).Normalized();
		float targetAngle = directionToTarget.Angle();
		
		float gunAngle = targetAngle + Mathf.Pi / 2;
		_gun.GlobalRotation = gunAngle;
	}
	
	private void MoveEnemy()
	{
		if (_nav2d == null) return;
		
		bool shouldMove = false;
		
		switch (_currentState)
		{
			case State.PATROL:
				shouldMove = true;
				break;
				
			case State.CHASE:
				shouldMove = !IsTargetVisible();
				break;
		}
		
		if (shouldMove && !_nav2d.IsNavigationFinished())
		{
			Vector2 nextLocation = _nav2d.GetNextLocation();
			Vector2 direction = (nextLocation - GlobalPosition).Normalized();
			
			float currentSpeed = _currentState == State.PATROL ? _patrolSpeed : _chaseSpeed;
			_velocity = direction * currentSpeed;
			
			if (_velocity.Length() > 0.1f)
			{
				RotationDegrees = _velocity.Angle() * 180 / Mathf.Pi + 90;
			}
			
			HandleMovementSound(_velocity);
		}
		else
		{
			_velocity = Vector2.Zero;
			HandleMovementSound(Vector2.Zero);
		}
	}

	private void UpdateRayCast()
	{
		if (_rayCast == null) return;
		
		Node2D target = GetCurrentTarget();
		if (target == null || !Godot.Object.IsInstanceValid(target)) return;
		
		Vector2 directionToTarget = (target.GlobalPosition - _bulletPosition.GlobalPosition).Normalized();
		float distanceToTarget = GlobalPosition.DistanceTo(target.GlobalPosition);
		
		_rayCast.CastTo = directionToTarget * distanceToTarget;
		_rayCast.Enabled = true;
	}

	private bool IsTargetVisible()
	{
		if (_rayCast == null) return false;
		
		if (_rayCast.IsColliding())
		{
			var collider = _rayCast.GetCollider();
			
			if (collider != null && Godot.Object.IsInstanceValid(collider))
			{
				if (collider == _player || collider == _base)
				{
					return true;
				}
			}
			return false;
		}
		
		Node2D target = GetCurrentTarget();
		return target != null && Godot.Object.IsInstanceValid(target);
	}

	private Node2D GetCurrentTarget()
	{
		if (_currentState == State.CHASE)
		{
			return (_player != null && Godot.Object.IsInstanceValid(_player)) ? _player : null;
		}
		else
		{
			return (_base != null && Godot.Object.IsInstanceValid(_base)) ? _base : null;
		}
	}

	private void CheckAndFire()
	{
		Node2D target = GetCurrentTarget();
		if (target == null) return;
		
		if (IsTargetVisible())
		{
			FireAtTarget(target);
		}
	}

	private void OnDetectionAreaEntered(Node body)
	{
		if (body == _player && Godot.Object.IsInstanceValid(_player))
		{
			_currentState = State.CHASE;
		}
	}

	private void OnDetectionAreaExited(Node body)
	{
		if (body == _player)
		{
			if (_base != null && Godot.Object.IsInstanceValid(_base))
			{
				_currentState = State.PATROL;
			}
		}
	}

	public void TakeDamage(int damage)
	{
		_hp -= damage;
		if (_hp <= 0)
		{
			Destroy();
		}
	}

	private void Destroy()
	{
		if (_player != null)
		{
			int reward = GetEnemyReward();
			_player.AddMoney(reward);
		}
		
		QueueFree();
	}
	private int GetEnemyReward()
	{
		switch (_typeEnemy)
		{
			case TypeEnemy.Light:
				return 50;
			case TypeEnemy.Medium:
				return 75;
			case TypeEnemy.Heavy:
				return 100;
			default:
				return 50;
		}
	}

	private void FireAtTarget(Node2D target)
	{
		if (_shootTimer.TimeLeft > 0)
			return;
			
		var bullet = (Bullet)bulletScene.Instance();
		
		float distance = GlobalPosition.DistanceTo(target.GlobalPosition);
		
		float baseAccuracy = 0.9f; 
		float distanceFactor = Mathf.Clamp(distance / 500f, 0f, 0.5f);
		float finalAccuracy = baseAccuracy - distanceFactor;
		
		Vector2 directionToTarget = (target.GlobalPosition - _gun.GlobalPosition).Normalized();
		float baseAngle = directionToTarget.Angle();
		float gunAngle = baseAngle + Mathf.Pi / 2;
		
		if (GD.Randf() > finalAccuracy) 
		{
			float missIntensity = 1f - finalAccuracy;
			float maxAngleOffset = Mathf.Deg2Rad(30f) * missIntensity;
			float randomOffset = (float)GD.RandRange(-maxAngleOffset, maxAngleOffset);
			
			float finalAngle = gunAngle + randomOffset;
			bullet.GlobalRotation = finalAngle; 
		}
		else
		{
			bullet.GlobalRotation = gunAngle; 
		}
		
		bullet.GlobalPosition = _bulletPosition.GlobalPosition;
		
		GetTree().Root.AddChild(bullet);
		bullet.init(TypeBullet.Plasma, false, _damage);
		var muzzleFlash = GetNode<AnimatedSprite>("ShotAnimation");
		if (muzzleFlash != null)
		{
	
			Vector2 bulletDirection = new Vector2(1, 0).Rotated(bullet.GlobalRotation);
			
			Vector2 flashPosition = _bulletPosition.GlobalPosition + bulletDirection * 25;
			
			muzzleFlash.GlobalPosition = flashPosition;
			muzzleFlash.Frame = 0;
			muzzleFlash.Play("Fire");
		}
		
		_shootTimer.Start();
		}
	
	private void fadeSound(){
		if (_tween.IsConnected("tween_completed", this, nameof(onTweenComplete)))
		{
			_tween.Disconnect("tween_completed", this, nameof(onTweenComplete));
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
		_tween.Connect("tween_completed", this, nameof(onTweenComplete));
	}
	
	private void onTweenComplete(Godot.Object obj, NodePath key)
	{
		_movingSound.Stop();
		_movingSound.VolumeDb = _normalMovementVolume;
	}
	
	private void init()
	{
		AddToGroup("enemies");
		_nav2d = GetNode<NavigationAgent2D>("NavigationAgent2D");
		_rayCast = GetNode<RayCast2D>("RayCast2D"); 
		_gun = GetNode<Sprite>("BodyTank/Gun");
		_body = GetNode<Sprite>("BodyTank");
		_movingSound = GetNode<AudioStreamPlayer>("MovingSound");
		_tween = new Tween();
		Navigation2D navigation2D = GetNode<Navigation2D>("/root/Field/Navigation2D");
		if (navigation2D != null)
		{
			_nav2d.SetNavigation(navigation2D);
		}
		RandomizeEnemyType();
		switch(_typeEnemy){
			case TypeEnemy.Light:
				_patrolSpeed = 110;
				_chaseSpeed = 120;
				_hp = 50;
				_damage = 10;
				_body.Texture = (Texture)GD.Load("res://assets/future_tanks/PNG/Hulls_Color_D/Hull_08.png");
				_gun.Texture = (Texture)GD.Load("res://assets/future_tanks/PNG/Weapon_Color_D/Gun_05.png");
				_gun.Position += new Vector2(0, -35);
				break;
			case TypeEnemy.Medium:
				_patrolSpeed = 100;
				_chaseSpeed = 105;
				_hp = 70;
				_damage = 25;
				_body.Texture = (Texture)GD.Load("res://assets/future_tanks/PNG/Hulls_Color_D/Hull_01.png");
				_gun.Texture = (Texture)GD.Load("res://assets/future_tanks/PNG/Weapon_Color_D/Gun_03.png");
				break;
			case TypeEnemy.Heavy:
				_patrolSpeed = 90;
				_chaseSpeed = 100;
				_hp = 100;
				_damage = 35;
				_body.Texture = (Texture)GD.Load("res://assets/future_tanks/PNG/Hulls_Color_D/Hull_02.png");
				_gun.Texture = (Texture)GD.Load("res://assets/future_tanks/PNG/Weapon_Color_D/Gun_08.png");
				break;
		}
		
		_currentState = State.PATROL;
		_detectionArea = GetNode<Area2D>("DetectionArea");
		_player = GetNode<Player>("/root/Field/PlayerTank");
		_base = GetNode<Base>("/root/Field/Base");
		_bulletPosition = GetNode<Position2D>("BodyTank/Gun/BulletPosition");
		
		_detectionArea.Connect("body_entered", this, nameof(OnDetectionAreaEntered));
		_detectionArea.Connect("body_exited", this, nameof(OnDetectionAreaExited));
		
		bulletScene = (PackedScene)GD.Load("res://scenes/Tank/Bullet.tscn");
		_shootTimer = new Timer();
		_shootTimer.WaitTime = 1f;
		_shootTimer.OneShot = true;
	}
	
	private void RandomizeEnemyType(){
		Array values = Enum.GetValues(typeof(TypeEnemy));
		Random random = new Random();
		_typeEnemy = (TypeEnemy)values.GetValue(random.Next(values.Length));
	}
}
