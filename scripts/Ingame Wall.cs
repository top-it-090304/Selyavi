using Godot;
using System;

public class DestroyableWall : StaticBody2D
{
	private bool _destroyable = true;

	public bool destroyable(){
		return _destroyable;
	}
}
