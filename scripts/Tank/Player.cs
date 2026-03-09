using Godot;
using System;


public partial class Player : CharacterBody2D
{
	#region private fields
	private int _speed = 250;
	private int _hp;
	private int _lives;
	private bool _isMoving = false;
	private bool _isScopeEnadled = true;
	private float _normalMovementVolume = 0f;
	private Settings SettingsCheckbox;
	private Vector2 _velocity = Vector2.Zero;
	private Marker2D _bulletPosition;
	private Timer _shootTimer;
	private AudioStreamPlayer _movingSound;
	private AudioStreamPlayer2D _shootSound;
	private Tween _tween;
	private CanvasLayer _joystick;
	private Sprite2D _gun;
	private MobileJoystick _aim;
	private TypeBullet _typeBullet = TypeBullet.Plasma;
	private Vector2 _startPosition;
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
		ConfigureAudioPlayers();
		if (_movingSound != null)
			{
				_normalMovementVolume = _movingSound.VolumeDb;
			}
			if (AudioManager.Instance != null)
			{
				if (!AudioManager.Instance.IsConnected(nameof(AudioManager.SfxVolumeChanged), new Callable(this, nameof(OnSfxVolumeChanged))))
				{
					AudioManager.Instance.Connect(nameof(AudioManager.SfxVolumeChanged), new Callable(this, nameof(OnSfxVolumeChanged)));
				}
			}
			
			if (GameManager.Instance != null)
			{
				if (!GameManager.Instance.IsConnected(nameof(GameManager.ScopeToggled), new Callable(this, nameof(ToggleScope))))
				{
					GameManager.Instance.Connect(nameof(GameManager.ScopeToggled), new Callable(this, nameof(ToggleScope)));
				}
				_isScopeEnadled = GameManager.Instance.ScopeEnabled;
			}
			else
			{
				LoadInitialScopeState();
			}
		}
		
		private void OnSfxVolumeChanged(float value)
		{
			float dbValue = GD.LinearToDb(value);
			_normalMovementVolume = dbValue;
			if (_movingSound.Playing)
			{
				_movingSound.VolumeDb = dbValue;
			}
			GD.Print("Громкость SFX изменена: ", value, " (", dbValue, " dB)");
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
	
	private void ToggleScope(bool checkboxValue){
		_isScopeEnadled = checkboxValue;
		Update();
	}
	private void ConfigureAudioPlayers()
	{
		int sfxBusIndex = AudioServer.GetBusIndex("SFX");
		
		if (_movingSound != null)
		{
		_movingSound.Bus = "SFX";
		}
		
	}
	
	private void useMoveVector(Vector2 moveVector){
		Vector2 joystickVelocity = moveVector * 200;
		MoveAndSlide(joystickVelocity);
		RotatePlayerMobile(moveVector);
		HandleMovementSound(joystickVelocity);
	}
	//public void getIsMovingNow(){
	//	return isMovingNow;
	//}
	private void HandleMovementSound(Vector2 movementVelocity){
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
			_movingSound.VolumeDb = _normalMovementVolume;
			if (!_movingSound.Playing)
			{
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
		bullet.init(_typeBullet, true);
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
		bool bulletChanged = false;
		if(Input.IsActionJustPressed("plasma")){
			_typeBullet = TypeBullet.Plasma;
			bulletChanged = true;
		} else{
			if(Input.IsActionJustPressed("medium_bullet")){
				_typeBullet = TypeBullet.Medium;
				bulletChanged = true;
			}else{
				if(Input.IsActionJustPressed("light_bullet")){
					_typeBullet = TypeBullet.Light3D;
					bulletChanged = true;
				}
			}
		}
		if (bulletChanged)
   		{
			_shootTimer.Start();
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
		RotationDegrees = Mathf.RadToDeg(direction.Angle()) + 90;
	}
	
	private void RotatePlayerMobileAim(Vector2 direction){
		_gun.GlobalRotationDegrees = Mathf.RadToDeg(direction.Angle()) + 90;
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
			FireTouch();
		}
	}
	public void TakeDamage(int damage){
		_hp -= damage;
		if(_hp <= 0){
			Destroy();
		}
	}
	
	private void Destroy(){
		_lives--;
		if(_lives != 0)
			Revive();
		else QueueFree();
	}
	
	private void Revive(){
		_hp = 20;
		GlobalPosition = _startPosition;
	}
	
	private void fadeSound(){
		if (_tween.IsConnected("tween_completed", new Callable(this, nameof(onTweenComplete))))
			{
				_tween.Disconnect("tween_completed", new Callable(this, nameof(onTweenComplete)));
			}
		if (_tween.IsActive())
		{
			_tween.StopAll();
			_tween.RemoveAll();
		}
		float currentVolume = _movingSound.VolumeDb;
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
		_tween.Connect("tween_completed", new Callable(this, nameof(onTweenComplete)));
	}
	
	private void onTweenComplete(Godot.Object obj, NodePath key)
	{
		_movingSound.Stop();
		_movingSound.VolumeDb = _normalMovementVolume;
	}

	 public override void _Process(float delta)
	 {
		Update();
	 }

	public override void _Draw()
{
	if(_aim.IsJoystickActive && _isScopeEnadled){
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
		bulletScene = (PackedScene)GD.Load("res://scenes/Tank/Bullet.tscn");
		_lives = 5;
		_hp = 20;
		_bulletPosition = GetNode<Marker2D>("BodyTank/Gun/BulletPosition");
		_movingSound = GetNode<AudioStreamPlayer>("MovingSound");
		_gun = GetNode<Sprite2D>("BodyTank/Gun");
		_joystick = GetNode<CanvasLayer>("Joystick");
		_aim = GetNode<MobileJoystick>("Aim");
		_startPosition = GlobalPosition;
		_aim.init(true);
		if (_aim != null)
		{
			_aim.init(true);
			if (!_aim.IsConnected("UseMoveVector", new Callable(this, nameof(useMoveVectorAim))))
			{
				_aim.Connect("UseMoveVector", new Callable(this, nameof(useMoveVectorAim)));
			}
			if (!_aim.IsConnected("FireTouch", new Callable(this, nameof(FireTouch))))
			{
				_aim.Connect("FireTouch", new Callable(this, nameof(FireTouch)));
			}
		}
		if (!_joystick.IsConnected("UseMoveVector", new Callable(this, nameof(useMoveVector))))
		{
			_joystick.Connect("UseMoveVector", new Callable(this, nameof(useMoveVector)));
		}
		if (!_aim.IsConnected("UseMoveVector", new Callable(this, nameof(useMoveVectorAim))))
		{
			_aim.Connect("UseMoveVector", new Callable(this, nameof(useMoveVectorAim)));
		}
		if (!_aim.IsConnected("FireTouch", new Callable(this, nameof(FireTouch))))
		{
			_aim.Connect("FireTouch", new Callable(this, nameof(FireTouch)));
		}
		_tween = new Tween();
		_shootTimer = new Timer();
		_shootTimer.WaitTime = 1f; 
		_shootTimer.OneShot = true;
	}
}

