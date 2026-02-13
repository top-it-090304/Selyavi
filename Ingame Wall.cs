using Godot;
using System;

public class IngameWall : StaticBody2D
{
	private bool _destroyable;
	public void destroy(){
		if (_destroyable){
			QueueFree();
		}
	}
	
	public bool destroyable(){
		return _destroyable;
	}
}
