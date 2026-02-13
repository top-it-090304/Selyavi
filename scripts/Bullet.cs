using Godot;
using System;

public class Bullet : Area2D
{
	private int _bulletSpeed = 7;
	private Vector2 _velocity = Vector2.Zero;
	private AudioStreamPlayer _plasmaSound;



	public override void _Ready()
	{
		_plasmaSound = GetNode<AudioStreamPlayer>("PlasmaGunSound");
		_velocity = new Vector2(0, -1).Rotated(Rotation);
	}
	
	private void move(){
		
		Position += _velocity * _bulletSpeed;
		
	}


  public override void _Process(float delta)
  {
	 move();
  }
}
