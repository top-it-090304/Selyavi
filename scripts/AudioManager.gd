extends Node

signal music_volume_changed(value)
signal sfx_volume_changed(value)

var _player: AudioStreamPlayer

var music_menu = preload("res://assets/Music/Hitman(chosic.com).mp3")
var music_boss = preload("res://assets/Music/Time-and-Space-Dramatic-Epic-Music(chosic.com).mp3")

# Звуки выстрелов
var sfx_plasma = preload("res://assets/sounds/plasma_gun_06.mp3")
var sfx_medium = preload("res://assets/sounds/vystrel-tanka.mp3")
var sfx_light = preload("res://assets/sounds/light_bullet.mp3")

enum Track { NONE, MENU, BOSS }
var current_track = Track.NONE

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	_player = AudioStreamPlayer.new()
	_player.bus = "Music" # Глобальная шина из default_bus_layout.tres
	add_child(_player)

	# Загружаем сохраненную громкость при старте
	if SaveManager:
		# Даем кадру пройти, чтобы AudioServer успел инициализироваться
		call_deferred("_init_volumes")

func _init_volumes():
	var music_vol = SaveManager.get_setting("audio", "music_volume", 1.0)
	var sfx_vol = SaveManager.get_setting("audio", "sfx_volume", 1.0)
	set_music_volume(music_vol)
	set_sfx_volume(sfx_vol)

func play_menu():
	if current_track == Track.MENU: return
	_play(music_menu)
	# Устанавливаем громкость плеера на -12 dB.
	# Это приглушит трек ОТНОСИТЕЛЬНО громкости шины "Music" в настройках.
	_player.volume_db = -12.0
	current_track = Track.MENU

func play_boss():
	if current_track == Track.BOSS: return
	_play(music_boss)
	# Музыка босса играет на 0 dB (в полную громкость шины "Music")
	_player.volume_db = 0.0
	current_track = Track.BOSS

func stop():
	_player.stop()
	current_track = Track.NONE

func _play(stream: AudioStream):
	if _player.stream == stream and _player.playing:
		return
	_player.stream = stream
	_player.play()

# Функции настройки AudioServer (эти шины созданы в Godot по умолчанию)
func set_music_volume(value: float):
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx != -1:
		# Используем логарифмическую шкалу для ползунка
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(max(0.0001, value)))
	music_volume_changed.emit(value)

func set_sfx_volume(value: float):
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx != -1:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(max(0.0001, value)))
	sfx_volume_changed.emit(value)

# Звук выстрела (привязан к шине SFX)
func play_bullet_sound(type: int, _pos: Vector2 = Vector2.ZERO):
	var sfx_player = AudioStreamPlayer.new()
	add_child(sfx_player)
	sfx_player.bus = "SFX"
	sfx_player.volume_db = -5.0 # Небольшое занижение для баланса

	match type:
		0: sfx_player.stream = sfx_plasma
		1: sfx_player.stream = sfx_medium
		2: sfx_player.stream = sfx_light
		_: sfx_player.stream = sfx_medium

	sfx_player.play()
	sfx_player.finished.connect(sfx_player.queue_free)
