using Godot;
using System;

public partial class Settings : Node2D
{
	private Slider _musicSlider;
	private Slider _soundSlider;
	private CheckButton _scopeToggler;
	
	public override void _Ready()
	{
		_musicSlider = GetNodeOrNull<Slider>("HSlider");
		_soundSlider = GetNodeOrNull<Slider>("HSlider2");
		_scopeToggler = GetNodeOrNull<CheckButton>("CheckButton");
		
		LoadSettings();
		
		if (_soundSlider != null)
			_soundSlider.Connect("value_changed", new Callable(this, nameof(OnSoundSliderChanged)));
		
		if (_musicSlider != null)
			_musicSlider.Connect("value_changed", new Callable(this, nameof(OnMusicSliderChanged)));
		
		if (_scopeToggler != null)
		{
			if (GameManager.Instance != null)
			{
				_scopeToggler.Pressed = GameManager.Instance.ScopeEnabled;
			}
			
			_scopeToggler.Connect("toggled", new Callable(this, nameof(_on_CheckButton_toggled)));
		}
	}

	private void OnMusicSliderChanged(float value)
	{
		AudioManager.Instance.SetMusicVolume(value);
		SaveSettings();
	}
	
	private void OnSoundSliderChanged(float value)
	{
		AudioManager.Instance.SetSfxVolume(value);
		SaveSettings(); 
	}
	
	private void _on_Return_Button_pressed()
	{
		SaveSettings();
		GetTree().ChangeSceneToFile("res://scenes/MenuScenes/Menu.tscn");
	}
	
	private void _on_CheckButton_toggled(bool buttonPressed)
	{
		if (GameManager.Instance != null)
		{
			GameManager.Instance.ScopeEnabled = buttonPressed;
		}
		
		SaveSettings(); 
	}
	
	private void LoadSettings()
	{
		var config = new ConfigFile();
		if (config.Load("user://settings.cfg") == Error.Ok)
		{
			if (_soundSlider != null)
				_soundSlider.Value = (float)config.GetValue("audio", "sfx_volume", 1.0f);
			
			if (_musicSlider != null)
				_musicSlider.Value = (float)config.GetValue("audio", "music_volume", 1.0f);
		}
	}
	
	private void SaveSettings()
	{
		var config = new ConfigFile();
		config.Load("user://settings.cfg"); 
		config.SetValue("audio", "sfx_volume", _soundSlider?.Value ?? 1.0f);
		config.SetValue("audio", "music_volume", _musicSlider?.Value ?? 1.0f);
		config.SetValue("game", "scope_enabled", _scopeToggler?.Pressed ?? true);
		config.Save("user://settings.cfg");
	}
}
