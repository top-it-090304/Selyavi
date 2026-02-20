using Godot;
using System;


public class IngameWall : StaticBody2D
{
	private bool _destroyable;
	private bool _can_player_pass;
	private int _player_speed;
	private bool _can_bullet_pass;
	
	public void destroy(){
		if (_destroyable){
			QueueFree();
		}
	}
	public bool destroyable(){
		return _destroyable;
	}
	public bool can_player_pass(){
		return _can_player_pass;
	}
	public int player_speed(){
		return _player_speed;
	}
	public bool can_bullet_pass(){
		return _can_bullet_pass;
	}
	
	public IngameWall(bool destroyable, bool canPlayerPass, int player_speed, bool canBulletPass)
	{
		_destroyable = destroyable;
		_can_player_pass = canPlayerPass;
		_player_speed = player_speed;
		_can_bullet_pass = canBulletPass;
	}

	public IngameWall() : this(false, false, 0, false)
	{
	}
}
