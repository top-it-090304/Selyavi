using Godot;
using System;


public class Enemy : KinematicBody2D
{
   
	private enum State{
		PATROL,
		CHASE
	}
	#region private fields
	private State _currentState;
	private Area2D _detectionArea;
	private int _hp = 10;
	private Player _player;
	[Export] private int _patrolSpeed = 90;
	[Export] private int _chaseSpeed = 100;
	private Vector2 _velocity = Vector2.Zero;
	private bool _isMovingRight = true;
	private bool _wasOnWallLastFrame = false;
	private Position2D _bulletPosition;
	private Timer _shootTimer;
	private Sprite _gun;
	

	private RayCast2D _rayForward;
	private RayCast2D _rayLeft;
	private RayCast2D _rayRight;
	private RayCast2D _rayLeftForward;
	private RayCast2D _rayRightForward;
	
	private Vector2 _avoidDirection = Vector2.Zero;
	private float _avoidTimer = 0f;
	private float _avoidTime = 0.5f;
	private float _rayDistance = 50f;
	#endregion
	PackedScene bulletScene;

	public override void _Ready()
	{
		init();
		AddChild(_shootTimer);
		SetupRayCasts();
	}
	
	private void SetupRayCasts()
	{

		_rayForward = CreateRay(Vector2.Right * _rayDistance);
		_rayLeft = CreateRay(Vector2.Up * _rayDistance);
		_rayRight = CreateRay(Vector2.Down * _rayDistance);
		_rayLeftForward = CreateRay((Vector2.Right + Vector2.Up).Normalized() * _rayDistance);
		_rayRightForward = CreateRay((Vector2.Right + Vector2.Down).Normalized() * _rayDistance);
	}
	
	private RayCast2D CreateRay(Vector2 castTo)
	{
		var ray = new RayCast2D();
		ray.Enabled = true;
		ray.CastTo = castTo;
		ray.CollisionMask = 1; 
		AddChild(ray);
		return ray;
	}
	
	private bool IsObstacleAhead()
	{
		return _rayForward.IsColliding() || 
			   _rayLeftForward.IsColliding() || 
			   _rayRightForward.IsColliding();
	}
	
	private Vector2 CalculateAvoidDirection()
	{

		bool leftFree = !_rayLeft.IsColliding();
		bool rightFree = !_rayRight.IsColliding();
		
		if (leftFree && !rightFree)
			return Vector2.Up;
		else if (rightFree && !leftFree)
			return Vector2.Down;
		else if (leftFree && rightFree)
		{

			if (_player != null && _currentState == State.CHASE)
			{
				Vector2 toPlayer = (_player.GlobalPosition - GlobalPosition).Normalized();
				float dotLeft = Vector2.Up.Dot(toPlayer);
				float dotRight = Vector2.Down.Dot(toPlayer);
				return dotLeft > dotRight ? Vector2.Up : Vector2.Down;
			}
			else
			{

				return (GD.Randi() % 2 == 0) ? Vector2.Up : Vector2.Down;
			}
		}
		
		return Vector2.Zero;
	}
	
	

	public override void _PhysicsProcess(float delta){
		switch (_currentState){
			case State.PATROL:
				if (_avoidTimer > 0)
				{
					_avoidTimer -= delta;
					_velocity = _avoidDirection * _patrolSpeed;
				}
				else if (IsObstacleAhead())
				{
					_avoidDirection = CalculateAvoidDirection();
					if (_avoidDirection != Vector2.Zero)
					{
						_avoidTimer = _avoidTime;
						_velocity = _avoidDirection * _patrolSpeed;
					}
				}
				else
				{
					_velocity.x = _isMovingRight ? _patrolSpeed : -_patrolSpeed;
					
					if (IsOnWall() && !_wasOnWallLastFrame)
					{
						_isMovingRight = !_isMovingRight;
						GetNode<Sprite>("BodyTank").FlipH = !_isMovingRight;
					}
				}
				
				_wasOnWallLastFrame = IsOnWall();
				if (_velocity != Vector2.Zero)
					RotationDegrees = Mathf.Rad2Deg(_velocity.Normalized().Angle()) + 90;
				break;

			case State.CHASE:
				if (_player != null)
				{
					Vector2 toPlayer = (_player.GlobalPosition - GlobalPosition).Normalized();
					
					if (_avoidTimer > 0)
					{
						_avoidTimer -= delta;
						_velocity = _avoidDirection * _chaseSpeed;
					}
					else if (IsObstacleAhead())
					{
						_avoidDirection = CalculateAvoidDirection();
						if (_avoidDirection != Vector2.Zero)
						{
							_avoidTimer = _avoidTime;
							_velocity = _avoidDirection * _chaseSpeed;
						}
					}
					else
					{
						_velocity = toPlayer * _chaseSpeed;
					}
					
					RotationDegrees = Mathf.Rad2Deg(_velocity.Normalized().Angle()) + 90;
					FireOnPlayer();
				}
				break;
		}

		_velocity = MoveAndSlide(_velocity);
}
	
	private void RotateRays()
	{

		_rayForward.CastTo = new Vector2(_rayDistance, 0).Rotated(Rotation);
		_rayLeft.CastTo = new Vector2(0, -_rayDistance).Rotated(Rotation);
		_rayRight.CastTo = new Vector2(0, _rayDistance).Rotated(Rotation);
		_rayLeftForward.CastTo = new Vector2(_rayDistance, -_rayDistance).Rotated(Rotation);
		_rayRightForward.CastTo = new Vector2(_rayDistance, _rayDistance).Rotated(Rotation);
	}
	
 	private void OnDetectionAreaEntered(Node body){
		if (body == _player)
		{
			_currentState = State.CHASE;
		}
	}

	private void OnDetectionAreaExited(Node body)
	{
		if (body == _player)
		{
			_currentState = State.PATROL;
			_avoidTimer = 0;
		}
	}
	
	public void TakeDamage(int damage){
		_hp -= damage;
		if(_hp <= 0){
			Destroy();
		}
	}
	
	private void Destroy(){
		QueueFree();
	}
	
	private void FireOnPlayer(){
		if (_shootTimer.TimeLeft > 0)
			return;
			
		var bullet = (Bullet)bulletScene.Instance();
		bullet.GlobalPosition = _bulletPosition.GlobalPosition;
		bullet.RotationDegrees = _gun.GlobalRotationDegrees;
		GetTree().Root.AddChild(bullet);
		bullet.init(TypeBullet.Plasma, false);
		_shootTimer.Start();
	}
	
	private void init(){
		_currentState = State.PATROL;
		_detectionArea = GetNode<Area2D>("DetectionArea");
		_player = GetNode<Player>("/root/Field/PlayerTank");
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
