using Godot;
using System;

public class Player : KinematicBody2D
{
	#region private fields
	private int _speed = 250;
	private bool _isMoving = false;
	private Vector2 _velocity = Vector2.Zero;
	private Position2D _bulletPosition;
	private Timer _shootTimer;
	private AudioStreamPlayer _movingSound;
	private Tween _tween;
	private CanvasLayer _joystick;
	private Sprite _gun;
	private MobileJoystick _aim;
	#endregion
	PackedScene bulletScene;
	
	public int Speed{
		get => _speed;
		set {
			if(value > 0 && value <= 800){
				_speed = value;
			}
		}
	}

	public override void _Ready()
	{
		bulletScene = (PackedScene)GD.Load("res://scenes/Bullet.tscn");
		_bulletPosition = GetNode<Position2D>("BodyTank/Gun/BulletPosition");
		_movingSound = GetNode<AudioStreamPlayer>("MovingSound");
		_gun = GetNode<Sprite>("BodyTank/Gun");
		_joystick = GetNode<CanvasLayer>("Joystick");
		_aim = GetNode<MobileJoystick>("Aim");
		_aim.isAim = true;
		if (!_joystick.IsConnected("UseMoveVector", this, nameof(useMoveVector)))
		{
			_joystick.Connect("UseMoveVector", this, nameof(useMoveVector));
		}
		if (!_aim.IsConnected("UseMoveVector", this, nameof(useMoveVectorAim)))
		{
			_aim.Connect("UseMoveVector", this, nameof(useMoveVectorAim));
		}
		if (!_aim.IsConnected("FireTouch", this, nameof(FireTouch)))
		{
			_aim.Connect("FireTouch", this, nameof(FireTouch));
		}
		_tween = new Tween();
		_shootTimer = new Timer();
		_shootTimer.WaitTime = 3f; 
		_shootTimer.OneShot = true;
		AddChild(_shootTimer);
		AddChild(_tween);

	}
	
	private void useMoveVector(Vector2 moveVector){
		MoveAndSlide(moveVector * 200);
		RotatePlayerMobile(moveVector);
	}
	
	private void FireTouch(){
		var bullet = (Area2D)bulletScene.Instance();
			bullet.GlobalPosition = _bulletPosition.GlobalPosition;
			bullet.RotationDegrees = _gun.GlobalRotationDegrees;
			bullet.GlobalPosition = _bulletPosition.GlobalPosition;
			GetTree().Root.AddChild(bullet);
			_shootTimer.Start();
	}
	private void useMoveVectorAim(Vector2 moveVector){
		RotatePlayerMobileAim(moveVector);
	}
	public override void _PhysicsProcess(float delta)
	{
		GetInput();
		_velocity = MoveAndSlide(_velocity);
	}
	private void GetInput()
	{
		move();
		//fire();
	}
	
	private void move(){
		_velocity.x = Input.GetActionStrength("move_right") - Input.GetActionStrength("move_left");
		_velocity.y = Input.GetActionStrength("move_down") - Input.GetActionStrength("move_up");

		if (_velocity.Length() > 0)
		{
			_velocity = _velocity.Normalized() * _speed;
			RotatePlayer(_velocity);
			if(!_isMoving){
				if(_tween.IsActive()){
					_tween.StopAll();
					_tween.RemoveAll(); 
					_movingSound.VolumeDb = 0;
				}
				_movingSound.VolumeDb = 0;
				_movingSound.Play();
				_isMoving = true;
			}
		} else {
			if(_isMoving){
				_isMoving = false;
				fadeSound();
			}

		}
	}
	
	private void RotatePlayerMobile(Vector2 direction){
		RotationDegrees = Mathf.Rad2Deg(direction.Angle()) + 90;
	}
	
	private void RotatePlayerMobileAim(Vector2 direction){
		_gun.RotationDegrees = Mathf.Rad2Deg(direction.Angle()) + 90;
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
			bullet.RotationDegrees = _gun.GlobalRotationDegrees;
			bullet.GlobalPosition = _bulletPosition.GlobalPosition;
			GetTree().Root.AddChild(bullet);
			_shootTimer.Start();
		}
	}
	
	private void fadeSound(){
		if (_tween.IsConnected("tween_completed", this, nameof(onTweenComplete)))
			{
				_tween.Disconnect("tween_completed", this, nameof(onTweenComplete));
			}
		_tween.InterpolateProperty(
			_movingSound,                    
			"volume_db",                   
			_movingSound.VolumeDb,         
			-80,                         
			0.5f,                          
			Tween.TransitionType.Linear,   
			Tween.EaseType.InOut          
		);
		_tween.Start();
		_tween.Connect("tween_completed", this, nameof(onTweenComplete));
	}
	
	private void onTweenComplete(Godot.Object obj, NodePath key)
{
	_movingSound.Stop();
	_movingSound.VolumeDb = 0;
}

	  /*public override void _Process(float delta)
	  {
		
	  }*/
}



