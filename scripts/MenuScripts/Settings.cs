using Godot;
using System;

public class Settings : Node2D
{
	private Slider _musicSlider;

	public override void _Ready()
	{
		_musicSlider = GetNodeOrNull<Slider>("HSlider");
		
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

	private void _on_Return_Button_pressed()
	{
		GetTree().ChangeScene("res://scenes/MenuScenes/Menu.tscn");
	}
}
