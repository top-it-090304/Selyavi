using Godot;
using System;

public class Settings : Node2D
{
	private Slider _musicSlider;
	private Slider _soundSlider;
	
	public override void _Ready()
	{
		_musicSlider = GetNodeOrNull<Slider>("HSlider");
		_soundSlider = GetNodeOrNull<Slider>("HSlider2");
		
		if (_soundSlider != null)
		{
			_soundSlider.Value = AudioManager.Instance.GetSfxVolume();
			
			if (!_soundSlider.IsConnected("value_changed", this, nameof(OnSoundSliderChanged)))
			{
				_soundSlider.Connect("value_changed", this, nameof(OnSoundSliderChanged));
			}
		}
		
		if (_musicSlider != null)
		{
			_musicSlider.Value = AudioManager.Instance.GetMusicVolume();
			
			if (!_musicSlider.IsConnected("value_changed", this, nameof(OnMusicSliderChanged)))
			{
				_musicSlider.Connect("value_changed", this, nameof(OnMusicSliderChanged));
			}
		}
	}

	private void OnMusicSliderChanged(float value)
	{
		AudioManager.Instance.SetMusicVolume(value);
	}
	
	private void OnSoundSliderChanged(float value)
	{
		AudioManager.Instance.SetSfxVolume(value);
	}
	
	private void _on_Return_Button_pressed()
	{
		GetTree().ChangeScene("res://scenes/MenuScenes/Menu.tscn");
	}
}
