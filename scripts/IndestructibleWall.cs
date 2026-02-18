using Godot;
using System;

public class IndestroyableWall : StaticBody2D
{
	private bool _destroyable = false;
	public void destroy(){
		if (_destroyable){
			QueueFree();
		}
	}
	
	public bool destroyable(){
		return _destroyable;
	}
}
