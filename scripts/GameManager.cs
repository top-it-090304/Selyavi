using Godot;
using System;

public partial class GameManager : Node
{
	private static GameManager _instance;
	public static GameManager Instance => _instance;
	
	[Signal] public delegate void ScopeToggled(bool enabled);
	
	private bool _scopeEnabled = true;
	
	public bool ScopeEnabled
	{
		get => _scopeEnabled;
		set
		{
			_scopeEnabled = value;
			EmitSignal(nameof(ScopeToggled), _scopeEnabled);
			SaveScopeState();
		}
	}
	
	public override void _Ready()
	{
		_instance = this;
		LoadSettings();
	}
	
	private void LoadSettings()
	{
		var config = new ConfigFile();
		if (config.Load("user://settings.cfg") == Error.Ok)
		{
			_scopeEnabled = (bool)config.GetValue("game", "scope_enabled", true);
		}
	}
	
	private void SaveScopeState()
	{
		var config = new ConfigFile();
		config.Load("user://settings.cfg");
		config.SetValue("game", "scope_enabled", _scopeEnabled);
		config.Save("user://settings.cfg");
	}
}
