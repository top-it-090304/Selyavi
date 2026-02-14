using Godot;
using System;

public class MobileJoystick : CanvasLayer
{
	[Signal]
	public delegate void UseMoveVector(Vector2 moveVector);
	
	#region private fields
	private TouchScreenButton _touchButton;
	private Vector2 moveVector = new Vector2(0, 0);
	private bool _isJoystickActive = false;
	private Sprite _innerCircle;
	private float _joystickRadius = 100f; // Радиус кнопки (половина размера)
	#endregion

	public override void _Ready()
	{
		_touchButton = GetNode<TouchScreenButton>("TouchScreenButton");
		_innerCircle = GetNode<Sprite>("JoystickTipArrows");
		ResetJoystick();
		
		// Можно автоматически определить радиус из размера текстуры
		// _joystickRadius = _touchButton.Texture.GetSize().x / 2;
	}
	
	public override void _Input(InputEvent @event)
	{
		if (@event is InputEventScreenTouch || @event is InputEventScreenDrag)
		{
			if (_touchButton.IsPressed())
			{
				Vector2 eventPosition = Vector2.Zero;
				
				if (@event is InputEventScreenTouch touchEvent)
					eventPosition = touchEvent.Position;
				else if (@event is InputEventScreenDrag dragEvent)
					eventPosition = dragEvent.Position;
				Vector2 buttonCenter = _touchButton.Position + new Vector2(_joystickRadius, _joystickRadius);
				Vector2 direction = eventPosition - buttonCenter;
				if (direction.Length() > _joystickRadius)
				{
					direction = direction.Normalized() * _joystickRadius;
				}
				_innerCircle.Position = buttonCenter + direction;
				moveVector = direction / _joystickRadius;
				_isJoystickActive = true;
			}
			else 
			{
				ResetJoystick();
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
		_innerCircle.Position = _touchButton.Position + new Vector2(_joystickRadius, _joystickRadius);
		moveVector = Vector2.Zero;
	}
}
