using Godot;
using System;

public class Base : Area2D
{
	public enum TypeBase{
		Player,
		Enemy
	}
	
	private Timer _spawnTimer;
	private Timer _healTimer;
	private Position2D _enemyPosition;
	PackedScene enemyScene;
	[Signal]
	public delegate void BaseState();
	
	[Export]
	public TypeBase typeBase;
	
	[Export] private int _maxEnemies = 3;
	[Export] private int _healAmount = 1;
	[Export] private float _healInterval = 1f;
	[Export] private float _healRadius = 100f;
	private float _timeSinceLastCheck = 0;
	private float _spawnRadius = 50f; 
	
	public override void _Ready()
	{
		Connect("area_entered", this, nameof(OnBodyEntered));
		enemyScene = (PackedScene)GD.Load("res://scenes/Tank/Enemy.tscn");
		_enemyPosition = GetNode<Position2D>("EnemyPosition");
		
		_spawnTimer = new Timer();
		_spawnTimer.WaitTime = 3f;
		_spawnTimer.OneShot = true;
		AddChild(_spawnTimer);
		
		_spawnTimer.Start(5f);
		_healTimer = new Timer();
		_healTimer.WaitTime = _healInterval;
		_healTimer.OneShot = false;
		AddChild(_healTimer);
		_healTimer.Connect("timeout", this, nameof(OnHealTimeout));
		_healTimer.Start();
	}
	
	private void OnBodyEntered(Node body)
	{
		if (body is Bullet bullet)
		{
			if ((bullet.IsPlayer && typeBase == TypeBase.Enemy) || (!bullet.IsPlayer && typeBase == TypeBase.Player))
				Destroy();
		}
	}
	
	private void OnHealTimeout()
	{
		if (typeBase != TypeBase.Player) return;
		
		Player player = GetNodeOrNull<Player>("/root/Field/PlayerTank");
		if (player == null) return;
		
		float distance = GlobalPosition.DistanceTo(player.GlobalPosition);
		if (distance <= _healRadius)
		{
			player.TakeHeal(_healAmount);
		}
	}
	
	public void Destroy()
	{
		EmitSignal(nameof(BaseState));
		QueueFree();
	}
	
	private int CountEnemiesOnScene()
	{
		var enemies = GetTree().GetNodesInGroup("enemies");
		return enemies.Count;
	}
	
	private bool IsEnemyOnBase()
	{
		var allEnemies = GetTree().GetNodesInGroup("enemies");
		foreach (Enemy enemy in allEnemies)
		{
			float distance = GlobalPosition.DistanceTo(enemy.GlobalPosition);
			if (distance < _spawnRadius)
			{
				return true;
			}
		}
		return false;
	}
	
	private void SpawnEnemy()
	{
		if (_spawnTimer.TimeLeft > 0)
			return;
		
		if (typeBase == TypeBase.Player)
			return;
		
		if (IsEnemyOnBase())
			return;
		
		int currentEnemies = CountEnemiesOnScene();
		
		if (currentEnemies >= _maxEnemies)
		{
			_spawnTimer.Start();
			return;
		}
		
		var enemy = (Enemy)enemyScene.Instance();
		enemy.GlobalPosition = _enemyPosition.GlobalPosition;
		GetTree().Root.AddChild(enemy);
		_spawnTimer.Start();
	}

	public override void _Process(float delta)
	{
		_timeSinceLastCheck += delta;
		if (_timeSinceLastCheck >= 0.5f)
		{
			SpawnEnemy();
			_timeSinceLastCheck = 0;
		}
	}
}
