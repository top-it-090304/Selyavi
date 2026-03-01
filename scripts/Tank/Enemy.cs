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
	private NavigationAgent2D _nav2d;
	private RayCast2D _rayCast;
	#endregion
	PackedScene bulletScene;

	public override void _Ready()
	{
		init();
		AddChild(_shootTimer);
		
		if (_nav2d != null)
		{
			_nav2d.MaxSpeed = _patrolSpeed;
			_nav2d.TargetDesiredDistance = 10f;
			_nav2d.PathDesiredDistance = 5f;
		}
	}

	public override void _PhysicsProcess(float delta)
	{
		UpdateTarget();
		MoveWithNavigation();
		UpdateRayCast();
		CheckAndFire();
		_velocity = MoveAndSlide(_velocity);
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

	private void UpdateRayCast()
	{
		if (_rayCast == null) return;
		
		Node2D target = GetCurrentTarget();
		if (target == null || !Godot.Object.IsInstanceValid(target)) return;
		
		Vector2 directionToTarget = (target.GlobalPosition - GlobalPosition).Normalized();
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
		
		if (!IsTargetVisible()) return;
		
		FireAtTarget(target);
	}

	private void MoveWithNavigation()
	{
		if (_nav2d == null) return;
		
		if (_nav2d.IsNavigationFinished())
		{
			_velocity = Vector2.Zero;
			return;
		}
		
		Vector2 nextLocation = _nav2d.GetNextLocation();
		Vector2 direction = (nextLocation - GlobalPosition).Normalized();
		
		float currentSpeed = _currentState == State.PATROL ? _patrolSpeed : _chaseSpeed;
		_velocity = direction * currentSpeed;
		
		if (_velocity.Length() > 0.1f)
		{
			RotationDegrees = _velocity.Angle() * 180 / Mathf.Pi + 90;
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
		QueueFree();
	}

	private void FireAtTarget(Node2D target)
	{
		if (_shootTimer.TimeLeft > 0)
			return;
			
		var bullet = (Bullet)bulletScene.Instance();
		
		bullet.GlobalPosition = _bulletPosition.GlobalPosition;
		bullet.GlobalRotation = _bulletPosition.GlobalRotation;
		
		GetTree().Root.AddChild(bullet);
		bullet.init(TypeBullet.Plasma, false);
		_shootTimer.Start();
	}

	private void init()
	{
		_nav2d = GetNode<NavigationAgent2D>("NavigationAgent2D");
		_rayCast = GetNode<RayCast2D>("RayCast2D"); 
		
		Navigation2D navigation2D = GetNode<Navigation2D>("/root/Field/Navigation2D");
		if (navigation2D != null)
		{
			_nav2d.SetNavigation(navigation2D);
		}
		
		_currentState = State.PATROL;
		_detectionArea = GetNode<Area2D>("DetectionArea");
		_player = GetNode<Player>("/root/Field/PlayerTank");
		_base = GetNode<Base>("/root/Field/Base");
		_gun = GetNode<Sprite>("BodyTank/Gun");
		_bulletPosition = GetNode<Position2D>("BodyTank/Gun/BulletPosition");
		
		_detectionArea.Connect("body_entered", this, nameof(OnDetectionAreaEntered));
		_detectionArea.Connect("body_exited", this, nameof(OnDetectionAreaExited));
		
		bulletScene = (PackedScene)GD.Load("res://scenes/Tank/Bullet.tscn");
		_shootTimer = new Timer();
		_shootTimer.WaitTime = 1f;
		_shootTimer.OneShot = true;
	}
}
