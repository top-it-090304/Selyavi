using Godot;
using System;

public class MobileJoystick : CanvasLayer
{
	[Signal]
	public delegate void UseMoveVector(Vector2 moveVector);
	
	[Signal]
	public delegate void FireTouch();
	
	#region private fields
	private TouchScreenButton _touchButton;
	private TouchScreenButton _fireButton;
	private Vector2 moveVector = new Vector2(0, 0);
	private bool _isJoystickActive = false;
	private Sprite _innerCircle;
	private float _joystickRadius = 100f; 
	private Vector2 _lastValidDirection = Vector2.Zero;
	private Vector2 _buttonCenter;
	private Texture _joystickTexture;
	#endregion
	
	
	public bool IsJoystickActive{
		get => _isJoystickActive;
	}
	
	public bool isAim = false;

	public override void _Ready()
	{
		Texture originalTexture = (Texture)GD.Load("res://assets/scope.png");
		Image image = originalTexture.GetData();
	
		image.Resize(100, 100, Image.Interpolation.Bilinear);
		ImageTexture resizedTexture = new ImageTexture();
		resizedTexture.CreateFromImage(image);
	
		_joystickTexture = resizedTexture;
		_touchButton = GetNode<TouchScreenButton>("TouchScreenButton");
		_fireButton = GetNode<TouchScreenButton>("JoystickTipArrows/FireButton");
		_innerCircle = GetNode<Sprite>("JoystickTipArrows");
		_buttonCenter = _touchButton.Position + new Vector2(_joystickRadius, _joystickRadius);
		ResetJoystick();
		_fireButton.Connect("released", this, nameof(OnButtonFirePressed));

	}
	
	public void init(bool aim){
		isAim = aim;
		if(isAim){
			_innerCircle.Texture = _joystickTexture;
		}
	}
	
	public override void _Input(InputEvent @event)
	{
		if (@event is InputEventScreenTouch || @event is InputEventScreenDrag)
		{
			if (_touchButton.IsPressed())
			{
				Vector2 eventPosition = Vector2.Zero;
				
				if (@event is InputEventScreenTouch touchEvent){
					eventPosition = touchEvent.Position;
				}
				else if (@event is InputEventScreenDrag dragEvent)
					eventPosition = dragEvent.Position;
				
				Vector2 localEventPos = eventPosition - GetFinalTransform().origin;
				Vector2 rawDirection = localEventPos - _buttonCenter;
				Vector2 clampedDirection;
				
				if (rawDirection.Length() > _joystickRadius)
				{
					clampedDirection = rawDirection.Normalized() * _joystickRadius;
				}
				else
				{
					clampedDirection = rawDirection;
				}
				
				_innerCircle.Position = _buttonCenter + clampedDirection;
				Vector2 newDirection = clampedDirection / _joystickRadius;
				
				if (isAim && _lastValidDirection != Vector2.Zero)
				{
					moveVector = _lastValidDirection.LinearInterpolate(newDirection, 0.3f);
				}
				else
				{
					moveVector = newDirection;
				}
				
				if (newDirection.Length() > 0.1f)
				{
					_lastValidDirection = newDirection;
				}
				
				_isJoystickActive = true;
			}
			else 
			{
				if(!isAim){
					ResetJoystick();
				}
				_isJoystickActive = false;
			}
		}
	}
	
	public override void _PhysicsProcess(float delta)
	{
		if(_isJoystickActive)
		{
			EmitSignal(nameof(UseMoveVector), moveVector);
		}
	}
	
	private void OnButtonFirePressed()
	{
		EmitSignal(nameof(FireTouch));
	}
	
	
	private void ResetJoystick()
	{
		_innerCircle.Position = _buttonCenter;
		moveVector = Vector2.Zero;
		_lastValidDirection = Vector2.Zero;
	}
}
