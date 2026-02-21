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
	private Player _player;
	[Export] private int _patrolSpeed = 90;
	[Export] private int _chaseSpeed = 100;
	private Vector2 _velocity = Vector2.Zero;
	private bool _isMovingRight = true;
	private bool _wasOnWallLastFrame = false;
	private Position2D _bulletPosition;
	private Timer _shootTimer;
	private Sprite _gun;
	#endregion
	PackedScene bulletScene;

	public override void _Ready()
	{
		init();
		AddChild(_shootTimer);
	}
	

	public override void _PhysicsProcess(float delta){
		switch (_currentState){
			case State.PATROL:
				_velocity.x = _isMovingRight ? _patrolSpeed : -_patrolSpeed;
				
				if (IsOnWall() && !_wasOnWallLastFrame)
				{
					_isMovingRight = !_isMovingRight;
					GetNode<Sprite>("BodyTank").FlipH = !_isMovingRight;
				}
				
				_wasOnWallLastFrame = IsOnWall();
				RotationDegrees = Mathf.Rad2Deg(_velocity.Normalized().Angle()) + 90;
				break;

			case State.CHASE:
				if (_player != null)
				{
					Vector2 direction = (_player.GlobalPosition - GlobalPosition).Normalized();
					RotationDegrees = Mathf.Rad2Deg(direction.Angle()) + 90;
					_velocity = direction * _chaseSpeed;
					FireOnPlayer();
				}
				break;
		}

		_velocity = MoveAndSlide(_velocity);
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
		}
	}
	
	private void FireOnPlayer(){
		if (_shootTimer.TimeLeft > 0)
			return;
			
		var bullet = (Bullet)bulletScene.Instance();
		bullet.GlobalPosition = _bulletPosition.GlobalPosition;
		bullet.RotationDegrees = _gun.GlobalRotationDegrees;
		bullet.GlobalPosition = _bulletPosition.GlobalPosition;
		GetTree().Root.AddChild(bullet);
		bullet.init(TypeBullet.Plasma);
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
	
  /*public override void _Process(float delta)
  {

  }*/

}
