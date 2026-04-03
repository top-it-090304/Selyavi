extends Node

const SAVE_FILE = "user://savegame.json"

var save_data = {
	"money": 0,
	"player_stats": {
		"body_type": 1,
		"gun_type": 1,
		"color_type": 0
	},
	"purchased": {
		"bodies": [1], # Средний корпус по умолчанию
		"guns": [1],   # Средняя пушка по умолчанию
		"colors": [0]  # Коричневый цвет по умолчанию
	}
}

var settings_data = {
	"audio": {
		"sfx_volume": 1.0,
		"music_volume": 1.0
	},
	"game": {
		"opt_scope_active": true
	}
}

const SETTINGS_FILE = "user://settings.cfg"

signal money_loaded(amount)
signal settings_changed

func _ready():
	load_game()
	load_settings()

func load_settings():
	var config = ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		settings_data.audio.sfx_volume = config.get_value("audio", "sfx_volume", 1.0)
		settings_data.audio.music_volume = config.get_value("audio", "music_volume", 1.0)
		settings_data.game.opt_scope_active = config.get_value("game", "scope_enabled", true)
	settings_changed.emit()

func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "sfx_volume", settings_data.audio.sfx_volume)
	config.set_value("audio", "music_volume", settings_data.audio.music_volume)
	config.set_value("game", "scope_enabled", settings_data.game.opt_scope_active)
	config.save(SETTINGS_FILE)

func get_setting(section: String, key: String, default):
	var k = key
	if k == "scope_enabled": k = "opt_scope_active"
	if settings_data.has(section) and settings_data[section].has(k):
		return settings_data[section][k]
	return default

func set_setting(section: String, key: String, value):
	var k = key
	if k == "scope_enabled": k = "opt_scope_active"
	if settings_data.has(section) and settings_data[section].has(k):
		settings_data[section][k] = value
		save_settings()
		settings_changed.emit()

# --- Сохранение и Загрузка ---

func save_game():
	# Обновляем деньги из игрока, если он активен
	var player_money = _get_money_from_active_player()
	if player_money != -1:
		save_data["money"] = player_money

	var file = FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file != null:
		var json_string = JSON.stringify(save_data)
		file.store_line(json_string)
		file.close()

func load_game():
	if not FileAccess.file_exists(SAVE_FILE):
		return

	var file = FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file != null:
		var json_string = file.get_as_text()
		file.close()

		var data = JSON.parse_string(json_string)
		if data is Dictionary:
			_merge_dict(save_data, data)
			money_loaded.emit(int(save_data.get("money", 0)))

# Рекурсивное слияние словарей для надежной загрузки
func _merge_dict(target: Dictionary, source: Dictionary):
	for key in source.keys():
		if target.has(key):
			if typeof(source[key]) == TYPE_DICTIONARY and typeof(target[key]) == TYPE_DICTIONARY:
				_merge_dict(target[key], source[key])
			else:
				target[key] = source[key]
		else:
			target[key] = source[key]

func _get_money_from_active_player() -> int:
	var player = get_tree().root.find_child("Player", true, false)
	if player == null: player = get_tree().root.find_child("PlayerTank", true, false)
	if player != null and player.has_method("get_money"):
		return player.get_money()
	return -1

func is_purchased(category: String, item_id: int) -> bool:
	if save_data.purchased.has(category):
		# Приводим к int, так как JSON может вернуть float
		for id in save_data.purchased[category]:
			if int(id) == item_id:
				return true
	return false

func add_purchased(category: String, item_id: int):
	if save_data.purchased.has(category):
		if not is_purchased(category, item_id):
			save_data.purchased[category].append(item_id)
			save_game()

func set_player_stat(stat: String, value: int):
	if save_data.player_stats.has(stat):
		save_data.player_stats[stat] = value
		save_game()

func get_player_stat(stat: String, default: int) -> int:
	return int(save_data.player_stats.get(stat, default))
