using Godot;
using System;

public class Bullet : Area2D
{
	#region private fields
	private int _bulletSpeed = 7;
	private Vector2 _velocity = Vector2.Zero;
	private AudioStreamPlayer _plasmaSound;
	#endregion
	
	public int BulletSpeed{
		get => _bulletSpeed;
		set {
			if(value > 0 && value <= 30){
				_bulletSpeed = value;
			}
		}
	}



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
