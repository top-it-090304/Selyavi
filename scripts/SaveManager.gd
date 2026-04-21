extends Node

const SAVE_FILE = "user://savegame.json"

var save_data = {
	"money": 0,
	"unlocked_levels": 1,
	"player_stats": {
		"body_type": 1,
		"gun_type": 1,
		"color_type": 0,
		"ammo_type": 0,
		"ammo_slot_0": 2,
		"ammo_slot_1": 0,
		"ammo_slot_2": 1,
		"base_hp_level": 0,
		"base_heal_level": 0,
		"base_bonus_level": 0,
		"base_feature_type": 0
	},
	"purchased": {
		"bodies": [1],
		"guns": [1],
		"colors": [0],
		"ammo_types": [0, 1, 2],
		"base_hp": [0],
		"base_heal": [0],
		"base_bonus": [0],
		"base_features": [0]
	}
}

var settings_data = {
	"audio": {
		"sfx_volume": 1.0,
		"music_volume": 1.0
	},
	"game": {
		"scope_enabled": true,
		"aim_assist": true,
		"lefty_mode": false,
		"camera_fov": 80.0,
		"marker_scale": 1.0,
		"graphics_quality": "high"
	}
}

const SETTINGS_FILE = "user://settings.cfg"

signal money_loaded(amount)
signal settings_changed

# Текущий выбранный уровень для логики сложности и спавна
var current_level: int = 1

func _ready():
	load_game()
	load_settings()

func load_settings():
	var config = ConfigFile.new()
	if config.load(SETTINGS_FILE) == OK:
		settings_data["audio"]["sfx_volume"] = config.get_value("audio", "sfx_volume", 1.0)
		settings_data["audio"]["music_volume"] = config.get_value("audio", "music_volume", 1.0)
		settings_data["game"]["scope_enabled"] = config.get_value("game", "scope_enabled", true)
		settings_data["game"]["aim_assist"] = config.get_value("game", "aim_assist", true)
		settings_data["game"]["lefty_mode"] = config.get_value("game", "lefty_mode", false)
		settings_data["game"]["camera_fov"] = config.get_value("game", "camera_fov", 80.0)
		settings_data["game"]["marker_scale"] = config.get_value("game", "marker_scale", 1.0)
		settings_data["game"]["graphics_quality"] = config.get_value("game", "graphics_quality", "high")
	_apply_graphics_quality(str(settings_data["game"].get("graphics_quality", "high")))
	settings_changed.emit()

func save_settings():
	var config = ConfigFile.new()
	config.set_value("audio", "sfx_volume", settings_data["audio"]["sfx_volume"])
	config.set_value("audio", "music_volume", settings_data["audio"]["music_volume"])
	config.set_value("game", "scope_enabled", settings_data["game"]["scope_enabled"])
	config.set_value("game", "aim_assist", settings_data["game"]["aim_assist"])
	config.set_value("game", "lefty_mode", settings_data["game"]["lefty_mode"])
	config.set_value("game", "camera_fov", settings_data["game"]["camera_fov"])
	config.set_value("game", "marker_scale", settings_data["game"]["marker_scale"])
	config.set_value("game", "graphics_quality", settings_data["game"]["graphics_quality"])
	config.save(SETTINGS_FILE)

func get_setting(section: String, key: String, default):
	if settings_data.has(section) and settings_data[section].has(key):
		return settings_data[section][key]
	return default

func set_setting(section: String, key: String, value):
	if not settings_data.has(section):
		settings_data[section] = {}

	settings_data[section][key] = value
	if section == "game" and key == "graphics_quality":
		_apply_graphics_quality(str(value))
	save_settings()
	settings_changed.emit()

func _apply_graphics_quality(quality: String):
	var viewport = get_viewport()

	if viewport == null:
		return

	match quality:
		"low":
			viewport.msaa_2d = Viewport.MSAA_DISABLED
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_DISABLED
			viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		"medium":
			viewport.msaa_2d = Viewport.MSAA_2X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR
		_:
			viewport.msaa_2d = Viewport.MSAA_4X
			viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

func save_game():
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
			for base_ammo in [0, 1, 2]:
				if not is_purchased("ammo_types", base_ammo):
					save_data.purchased["ammo_types"].append(base_ammo)
			money_loaded.emit(int(save_data.get("money", 0)))

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
		for id in save_data.purchased[category]:
			if int(id) == item_id:
				return true
	return false

func add_purchased(category: String, item_id: int):
	if not save_data.purchased.has(category):
		save_data.purchased[category] = []

	if not is_purchased(category, item_id):
		save_data.purchased[category].append(item_id)
		save_game()

func set_player_stat(stat: String, value: int):
	if save_data.player_stats.has(stat):
		save_data.player_stats[stat] = value
		save_game()

func get_player_stat(stat: String, default: int) -> int:
	return int(save_data.player_stats.get(stat, default))

func unlock_level(level_num: int):
	# Только увеличиваем уровень, не позволяем сбрасывать назад через UI
	if level_num > save_data.get("unlocked_levels", 1):
		save_data["unlocked_levels"] = level_num
		save_game()

func reset_progress():
	save_data = {
		"money": 0,
		"unlocked_levels": 1,
		"player_stats": {
			"body_type": 1,
			"gun_type": 1,
			"color_type": 0,
			"base_hp_level": 0,
			"base_heal_level": 0,
			"base_bonus_level": 0,
			"base_feature_type": 0
		},
		"purchased": {
			"bodies": [1],
			"guns": [1],
			"colors": [0],
			"base_hp": [0],
			"base_heal": [0],
			"base_bonus": [0],
			"base_features": [0]
		}
	}
	save_game()
	money_loaded.emit(0)
