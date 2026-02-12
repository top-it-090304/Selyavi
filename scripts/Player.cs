using Godot;
using System;

public class Player : KinematicBody2D
{
	
	private int _speed = 250;
	private Vector2 _velocity = Vector2.Zero;
	
	private Position2D _bulletPosition;
	private Timer _shootTimer;
	PackedScene bulletScene = (PackedScene)GD.Load("res://scenes/Bullet.tscn");
	


	public override void _Ready()
	{
		_bulletPosition = GetNode<Position2D>("BodyTank/Gun/BulletPosition");
		_shootTimer = new Timer();
		_shootTimer.WaitTime = 3f; 
		_shootTimer.OneShot = true;
		AddChild(_shootTimer);

	}
	public override void _PhysicsProcess(float delta)
	{
		GetInput();
		_velocity = MoveAndSlide(_velocity);
	}
	private void GetInput()
	{
		move();
		fire();
		
	}
	
	private void move(){
		_velocity.x = Input.GetActionStrength("move_right") - Input.GetActionStrength("move_left");
		_velocity.y = Input.GetActionStrength("move_down") - Input.GetActionStrength("move_up");

		if (_velocity.Length() > 0)
		{
			_velocity = _velocity.Normalized() * _speed;
			RotatePlayer(_velocity);
		}
	}
	
	private void RotatePlayer(Vector2 direction){
		if(direction.x > 0) {
			if(direction.y < 0){
				RotationDegrees = 45;
			} else {
				if(direction.y > 0){
					RotationDegrees = 90 + 45;
				}
				else RotationDegrees = 90;
			}

		} else if(direction.x < 0){
			if(direction.y < 0){
				RotationDegrees = 270 + 45;
			} else {
				if(direction.y > 0){
					RotationDegrees = 270 - 45;
				}
				else RotationDegrees = 270;
			}

		}
		else if (direction.y > 0) 
		{
			RotationDegrees = 180;
		}
		else if (direction.y < 0) 
		{
			RotationDegrees = 0;
		}
		
	}
	
	private void fire(){
		if(Input.IsActionJustPressed("fire")){
			var bullet = (Area2D)bulletScene.Instance();
			bullet.GlobalPosition = _bulletPosition.GlobalPosition;
			bullet.RotationDegrees = RotationDegrees;
			bullet.GlobalPosition = _bulletPosition.GlobalPosition;
			bullet.RotationDegrees = RotationDegrees; 
			GetTree().Root.AddChild(bullet);
			_shootTimer.Start();
		}
	}


	  /*public override void _Process(float delta)
	  {
		
	  }*/
}
