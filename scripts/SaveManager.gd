extends Node

const SAVE_FILE = "user://savegame.save"
const SETTINGS_FILE = "user://settings.cfg"

var save_data = {
	"money": 0,
	"player_stats": {
		"body_type": 1,  # Medium
		"gun_type": 1,   # Medium
		"color_type": 0  # Brown
	}
}

signal money_loaded(amount)

func _ready():
	load_game()

func save_game():
	var file = File.new()
	var error = file.open(SAVE_FILE, File.WRITE)
	
	if error == OK:
		var money = get_money_from_player()
		money = clamp(money, 0, 99999)
		save_data["money"] = money
		var player_stats = save_data.get("player_stats", {})
		player_stats["body_type"] = clamp(player_stats.get("body_type", 1), 0, 4)
		player_stats["gun_type"] = clamp(player_stats.get("gun_type", 1), 0, 4)
		player_stats["color_type"] = clamp(player_stats.get("color_type", 0), 0, 2)
		save_data["player_stats"] = player_stats
		
		file.store_line(to_json(save_data))
		file.close()
		print("Game saved successfully with money: ", money)
	else:
		print("Error saving game: ", error)

func load_game():
	var file = File.new()
	
	if file.file_exists(SAVE_FILE):
		var error = file.open(SAVE_FILE, File.READ)
		
		if error == OK:
			var data = parse_json(file.get_as_text())
			file.close()
			
			if data != null:
				save_data = data
				var money = save_data.get("money", 0)
				money = clamp(money, 0, 99999)
				
				if money != save_data["money"]:
					save_data["money"] = money
					print("Money adjusted to: ", money)
				
				emit_signal("money_loaded", save_data["money"])
				print("Game loaded successfully: ", save_data["money"], " money")
			else:
				print("Error parsing save data")
		else:
			print("Error loading game: ", error)
	else:
		print("No save file found, starting new game")

func get_money_from_player() -> int:
	var player = get_tree().get_root().find_node("Player", true, false)
	if player == null:
		player = get_tree().get_root().find_node("PlayerTank", true, false)
	
	if player != null and player.has_method("get_money"):
		return player.get_money()
	
	return 0

func apply_saved_money():
	var player = get_tree().get_root().find_node("Player", true, false)
	if player == null:
		player = get_tree().get_root().find_node("PlayerTank", true, false)
	
	if player != null and player.has_method("add_money"):
		player.add_money(save_data["money"])
		print("Applied saved money: ", save_data["money"])
