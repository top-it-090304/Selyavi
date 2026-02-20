using Godot;
using System;

public class AudioManager : Node
{
	public static AudioManager Instance { get; private set; }
	
	[Signal] public delegate void MusicVolumeChanged(float value);
	[Signal] public delegate void SfxVolumeChanged(float value);
	
	private int _musicBusIndex;
	private int _sfxBusIndex;

	public override void _Ready()
	{
		Instance = this;
		
		CheckAllBuses();
		LoadSettings();
		SetMusicVolume(1.0f);
	}
	
	private void CheckAllBuses()
	{
		for (int i = 0; i < AudioServer.GetBusCount(); i++)
		{
			string busName = AudioServer.GetBusName(i);
			float volume = AudioServer.GetBusVolumeDb(i);
		}
		_musicBusIndex = FindBusIndex("Music");
		_sfxBusIndex = FindBusIndex("SFX");
	}
	
	private int FindBusIndex(string busName)
	{
		for (int i = 0; i < AudioServer.GetBusCount(); i++)
		{
			if (AudioServer.GetBusName(i) == busName)
			{
				return i;
			}
		}
		return 0;
	}

	public void SetMusicVolume(float value)
	{
		float dbValue = GD.Linear2Db(value);
		AudioServer.SetBusVolumeDb(_musicBusIndex, dbValue);
		EmitSignal(nameof(MusicVolumeChanged), value);
		SaveSetting("music_volume", value);
	}

	public void SetSfxVolume(float value)
	{
		float dbValue = GD.Linear2Db(value);
		AudioServer.SetBusVolumeDb(_sfxBusIndex, dbValue);
		EmitSignal(nameof(SfxVolumeChanged), value);
		SaveSetting("sfx_volume", value);
	}

	public float GetMusicVolume()
	{
		float dbValue = AudioServer.GetBusVolumeDb(_musicBusIndex);
		float linear = GD.Db2Linear(dbValue);
		return linear;
	}

	public float GetSfxVolume()
	{
		float dbValue = AudioServer.GetBusVolumeDb(_sfxBusIndex);
		return GD.Db2Linear(dbValue);
	}

	private void SaveSetting(string key, float value)
	{
		var config = new ConfigFile();
		config.Load("user://settings.cfg");
		config.SetValue("audio", key, value);
		config.Save("user://settings.cfg");
	}

	private void LoadSettings()
	{
		var config = new ConfigFile();
		if (config.Load("user://settings.cfg") == Error.Ok)
		{
			float musicVol = (float)config.GetValue("audio", "music_volume", 0.8f);
			float sfxVol = (float)config.GetValue("audio", "sfx_volume", 0.8f);
			
			SetMusicVolume(musicVol);
			SetSfxVolume(sfxVol);
			
		}
		else
		{
			SetMusicVolume(0.8f);
			SetSfxVolume(0.8f);
		}
	}
}
