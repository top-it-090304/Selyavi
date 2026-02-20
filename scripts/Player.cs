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
	private TypeBullet _typeBullet = TypeBullet.Plasma;
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
		init();
		AddChild(_shootTimer);
		AddChild(_tween);

	}
	
	private void useMoveVector(Vector2 moveVector){
		Vector2 joystickVelocity = moveVector * 200;
		MoveAndSlide(joystickVelocity);
		RotatePlayerMobile(moveVector);
		HandleMovementSound(joystickVelocity);
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
			

			if (!_movingSound.Playing)
			{
				_movingSound.VolumeDb = 0;
				_movingSound.Play();
			}
			
			_isMoving = true;
		}
	} 
	else 
	{

		if(_isMoving)
		{
			_isMoving = false;
			

			if (_movingSound.Playing)
			{
				fadeSound();
			}
		}
	}
}
	private void FireTouch(){
		if (_shootTimer.TimeLeft > 0)
			return;
			
		var bullet = (Bullet)bulletScene.Instance();
		bullet.GlobalPosition = _bulletPosition.GlobalPosition;
		bullet.RotationDegrees = _gun.GlobalRotationDegrees;
		bullet.GlobalPosition = _bulletPosition.GlobalPosition;
		GetTree().Root.AddChild(bullet);
		bullet.init(_typeBullet);
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
		changeBullet();
		//fire();
	}
	
	private void changeBullet(){
		if(Input.IsActionJustPressed("plasma")){
			_typeBullet = TypeBullet.Plasma;
		} else{
			if(Input.IsActionJustPressed("medium_bullet")){
				_typeBullet = TypeBullet.Medium;
			}
			if(Input.IsActionJustPressed("light_bullet")){
				_typeBullet = TypeBullet.Light;
			}
		}
	}
	
	private void move(){
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
	
	private void RotatePlayerMobile(Vector2 direction){
		RotationDegrees = Mathf.Rad2Deg(direction.Angle()) + 90;
	}
	
	private void RotatePlayerMobileAim(Vector2 direction){
		_gun.GlobalRotationDegrees = Mathf.Rad2Deg(direction.Angle()) + 90;
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

	 public override void _Process(float delta)
	  {
		Update();
	  }
	
	public override void _Draw()
{
	if(_aim.IsJoystickActive){
		Vector2 globalMuzzlePos = _bulletPosition.GlobalPosition;
		
		float gunAngle = _gun.GlobalRotation;
		Vector2 direction = new Vector2(1, 0).Rotated(gunAngle);
		
		Vector2 perpendicular = new Vector2(direction.y, -direction.x);
		
		float rayLength = 1000f;
		
		Vector2 globalRayEnd = globalMuzzlePos + perpendicular * rayLength;
		
		Vector2 localMuzzlePos = ToLocal(globalMuzzlePos);
		Vector2 localRayEnd = ToLocal(globalRayEnd);
		
		Color rayColor = Colors.Red;
		float rayWidth = 2f;
		DrawLine(localMuzzlePos, localRayEnd, rayColor, rayWidth);

	}
}
	
	private void init(){
		bulletScene = (PackedScene)GD.Load("res://scenes/Bullet.tscn");
		_bulletPosition = GetNode<Position2D>("BodyTank/Gun/BulletPosition");
		_movingSound = GetNode<AudioStreamPlayer>("MovingSound");
		_gun = GetNode<Sprite>("BodyTank/Gun");
		_joystick = GetNode<CanvasLayer>("Joystick");
		_aim = GetNode<MobileJoystick>("Aim");
		_aim.init(true);
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
		_shootTimer.WaitTime = 1f; 
		_shootTimer.OneShot = true;
	}
}



