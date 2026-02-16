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
	private Vector2 moveVector = new Vector2(0, 0);
	private bool _isJoystickActive = false;
	private Sprite _innerCircle;
	private float _joystickRadius = 100f; 
	private Vector2 _lastValidDirection = Vector2.Zero;
	private Vector2 _buttonCenter;
	#endregion
	
	public bool isAim = false;

	public override void _Ready()
	{
		_touchButton = GetNode<TouchScreenButton>("TouchScreenButton");
		_innerCircle = GetNode<Sprite>("JoystickTipArrows");
		_buttonCenter = _touchButton.Position + new Vector2(_joystickRadius, _joystickRadius);
		ResetJoystick();
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
					EmitSignal(nameof(FireTouch));
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
	
	private void ResetJoystick()
	{
		_innerCircle.Position = _buttonCenter;
		moveVector = Vector2.Zero;
		_lastValidDirection = Vector2.Zero;
	}
}
