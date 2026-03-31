extends Node

signal music_volume_changed(value)
signal sfx_volume_changed(value)

var _music_bus_index: int
var _sfx_bus_index: int
var _bullet_sound_players: Dictionary = {}
var _bullet_last_play_time: Dictionary = {}
var _min_bullet_interval: float = 0.15

func play_bullet_sound(type: int, global_position: Vector2):
	var current_time = Time.get_ticks_msec() / 1000.0
	if _bullet_last_play_time.has(type) and current_time - _bullet_last_play_time[type] < _min_bullet_interval:
		return
	_bullet_last_play_time[type] = current_time
	
	if not _bullet_sound_players.has(type):
		var sound = AudioStreamPlayer.new()
		sound.bus = "SFX"
		sound.volume_db = -15.0
		
		var path = ""
		match type:
			0:  # TypeBullet.Plasma
				path = "res://assets/sounds/plasma_gun_06.mp3"
			1:  # TypeBullet.Medium
				path = "res://assets/sounds/vystrel-tanka.mp3"
			2:  # TypeBullet.Light
				path = "res://assets/sounds/light_bullet.mp3"
		
		sound.stream = load(path)
		add_child(sound)
		_bullet_sound_players[type] = sound
	
	_bullet_sound_players[type].play()

func _ready():
	_check_all_buses()
	_load_settings()
	set_music_volume(1.0)

func _check_all_buses():
	for i in range(AudioServer.get_bus_count()):
		var bus_name = AudioServer.get_bus_name(i)
		var volume = AudioServer.get_bus_volume_db(i)
	
	_music_bus_index = _find_bus_index("Music")
	_sfx_bus_index = _find_bus_index("SFX")

func _find_bus_index(bus_name: String) -> int:
	for i in range(AudioServer.get_bus_count()):
		if AudioServer.get_bus_name(i) == bus_name:
			return i
	return 0

func set_music_volume(value: float):
	var db_value = linear2db(value)
	AudioServer.set_bus_volume_db(_music_bus_index, db_value)
	emit_signal("music_volume_changed", value)
	_save_setting("music_volume", value)

func set_sfx_volume(value: float):
	var db_value = linear2db(value)
	AudioServer.set_bus_volume_db(_sfx_bus_index, db_value)
	emit_signal("sfx_volume_changed", value)
	_save_setting("sfx_volume", value)

func get_music_volume() -> float:
	var db_value = AudioServer.get_bus_volume_db(_music_bus_index)
	return db2linear(db_value)

func get_sfx_volume() -> float:
	var db_value = AudioServer.get_bus_volume_db(_sfx_bus_index)
	return db2linear(db_value)

func _save_setting(key: String, value: float):
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("audio", key, value)
	config.save("user://settings.cfg")

func _load_settings():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		var music_vol = config.get_value("audio", "music_volume", 0.8)
		var sfx_vol = config.get_value("audio", "sfx_volume", 0.8)
		set_music_volume(music_vol)
		set_sfx_volume(sfx_vol)
	else:
		set_music_volume(0.8)
		set_sfx_volume(0.8)
