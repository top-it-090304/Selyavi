using Godot;
using System;

public class Base : Area2D
{
	
	[Signal]
	public delegate void BaseState(bool IsDestroy);
	
	
	public override void _Ready()
	{
		Connect("area_entered", this, nameof(OnBodyEntered));
	}
	
	private void OnBodyEntered(Node body)
	{
	
		if (body is Bullet)
		{
			Destroy();
		}
	}
	
	private void Destroy()
	{
		EmitSignal(nameof(BaseState), true);
		QueueFree();
	}
	


//  public override void _Process(float delta)
//  {
//      
//  }
}
