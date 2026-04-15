extends "res://scripts/Field.gd"

func _ready():
	# Копируем логику _ready из Field.gd, НО без запуска туториала

	# 1. Номер уровня - для песочницы можно поставить 99 или оставить текущий
	if SaveManager:
		# Чтобы спавнились все типы врагов, поставим уровень выше 5
		SaveManager.current_level = 99
		current_level = 99

	# 2. Музыка
	_musicPlayer = get_node_or_null("MusicPlayer")
	var am = get_node_or_null("/root/AudioManager")

	if _musicPlayer != null:
		_musicPlayer.bus = "Music"
		if am: am.stop()
		_musicPlayer.play()

	# 3. Следим за объектами
	get_tree().node_added.connect(_on_node_added)

	for node in get_tree().get_nodes_in_group("bases"):
		_connect_base(node)

	for node in get_tree().get_nodes_in_group("enemies"):
		_connect_enemy(node)

	# 4. Таймер подстраховки
	_victory_timer = Timer.new()
	_victory_timer.wait_time = 1.0
	_victory_timer.autostart = true
	_victory_timer.timeout.connect(_check_victory_conditions)
	add_child(_victory_timer)

	_pauseScene = load("res://scenes/MenuScenes/PauseScreen.tscn")
	call_deferred("_connect_player_lives")

	# ТУТОРИАЛ НЕ ЗАПУСКАЕМ
