extends Control

@onready var tank_preview_body = $TankFrame/TankPreview/Body
@onready var tank_preview_gun = $TankFrame/TankPreview/Body/Gun
@onready var money_label = $MoneyLabel

@onready var damage_label = $Stats/Damage
@onready var hp_label = $Stats/HP
@onready var speed_label = $Stats/Speed
@onready var rof_label = $Stats/ROF

@onready var buy_button = $BuyButton
@onready var status_label = $BuyButton/StatusLabel

# Item Data
var bodies = [
	{"id": 0, "name": "Light Hull", "price": 500, "hp": 80, "speed": 300, "file": "Hull_05"},
	{"id": 1, "name": "Medium Hull", "price": 0, "hp": 100, "speed": 250, "file": "Hull_02"},
	{"id": 2, "name": "Heavy Hull", "price": 1000, "hp": 150, "speed": 180, "file": "Hull_06"},
	{"id": 3, "name": "L-Medium Hull", "price": 750, "hp": 120, "speed": 220, "file": "Hull_01"},
	{"id": 4, "name": "M-Heavy Hull", "price": 1200, "hp": 135, "speed": 200, "file": "Hull_03"}
]

var guns = [
	{"id": 0, "name": "Light Gun", "price": 400, "dmg_mod": 0.8, "rof": 0.5, "file": "Gun_01"},
	{"id": 1, "name": "Medium Gun", "price": 0, "dmg_mod": 1.0, "rof": 1.0, "file": "Gun_03"},
	{"id": 2, "name": "Heavy Gun", "price": 1000, "dmg_mod": 1.5, "rof": 2.5, "file": "Gun_08"},
	{"id": 3, "name": "L-Medium Gun", "price": 600, "dmg_mod": 1.1, "rof": 0.8, "file": "Gun_04"},
	{"id": 4, "name": "M-Heavy Gun", "price": 900, "dmg_mod": 1.3, "rof": 1.8, "file": "Gun_07"}
]

var colors = [
	{"id": 0, "name": "Brown", "price": 0, "hp_bonus": 0, "speed_bonus": 0, "rof_bonus": 0, "folder": "Color_A"},
	{"id": 1, "name": "Green", "price": 300, "hp_bonus": 10, "speed_bonus": 20, "rof_bonus": -0.1, "folder": "Color_B"},
	{"id": 2, "name": "Azure", "price": 500, "hp_bonus": 20, "speed_bonus": -10, "rof_bonus": -0.2, "folder": "Color_C"}
]

var current_body_idx = 0
var current_gun_idx = 0
var current_color_idx = 0

var money = 0

func _ready():
	# Load current selection from SaveManager
	current_body_idx = SaveManager.get_player_stat("body_type", 1)
	current_gun_idx = SaveManager.get_player_stat("gun_type", 1)
	current_color_idx = SaveManager.get_player_stat("color_type", 0)

	if SaveManager.has_method("get_money_from_active_player"):
		var m = SaveManager._get_money_from_active_player()
		if m != -1: money = m
		else: money = SaveManager.save_data.get("money", 0)
	else:
		money = SaveManager.save_data.get("money", 0)

	update_ui()

func update_ui():
	money_label.text = "Money: " + str(money)

	var body = bodies[current_body_idx]
	var gun = guns[current_gun_idx]
	var color = colors[current_color_idx]

	# Update Preview
	var body_path = "res://assets/future_tanks/PNG/Hulls_" + color.folder + "/" + body.file + ".png"
	var gun_path = "res://assets/future_tanks/PNG/Weapon_" + color.folder + "/" + gun.file + ".png"

	tank_preview_body.texture = load(body_path)
	tank_preview_gun.texture = load(gun_path)

	# Update Stats
	damage_label.text = "Damage: x" + str(gun.dmg_mod)
	hp_label.text = "HP: " + str(body.hp + color.hp_bonus)
	speed_label.text = "Speed: " + str(body.speed + color.speed_bonus)
	rof_label.text = "Reload: " + str(gun.rof + color.rof_bonus) + "s"

	# Check Buy Button
	_update_buy_button()

	# Update selector names (assuming labels exist)
	$Selectors/GunSelector/Label.text = gun.name
	$Selectors/HullSelector/Label.text = body.name
	$Selectors/ColorSelector/Label.text = color.name

func _update_buy_button():
	var body_owned = SaveManager.is_purchased("bodies", current_body_idx)
	var gun_owned = SaveManager.is_purchased("guns", current_gun_idx)
	var color_owned = SaveManager.is_purchased("colors", current_color_idx)

	var all_owned = body_owned and gun_owned and color_owned

	if all_owned:
		var is_equipped = (current_body_idx == SaveManager.get_player_stat("body_type", -1) and
						   current_gun_idx == SaveManager.get_player_stat("gun_type", -1) and
						   current_color_idx == SaveManager.get_player_stat("color_type", -1))

		if is_equipped:
			buy_button.disabled = true
			status_label.text = "Equipped"
		else:
			buy_button.disabled = false
			status_label.text = "Equip"
	else:
		var total_cost = 0
		if not body_owned: total_cost += bodies[current_body_idx].price
		if not gun_owned: total_cost += guns[current_gun_idx].price
		if not color_owned: total_cost += colors[current_color_idx].price

		status_label.text = "Buy: " + str(total_cost)
		buy_button.disabled = (money < total_cost)

func _on_buy_button_pressed():
	var body_owned = SaveManager.is_purchased("bodies", current_body_idx)
	var gun_owned = SaveManager.is_purchased("guns", current_gun_idx)
	var color_owned = SaveManager.is_purchased("colors", current_color_idx)

	if body_owned and gun_owned and color_owned:
		# Just equip
		SaveManager.set_player_stat("body_type", current_body_idx)
		SaveManager.set_player_stat("gun_type", current_gun_idx)
		SaveManager.set_player_stat("color_type", current_color_idx)
		update_ui()
		return

	var total_cost = 0
	if not body_owned: total_cost += bodies[current_body_idx].price
	if not gun_owned: total_cost += guns[current_gun_idx].price
	if not color_owned: total_cost += colors[current_color_idx].price

	if money >= total_cost:
		money -= total_cost
		SaveManager.save_data["money"] = money

		if not body_owned: SaveManager.add_purchased("bodies", current_body_idx)
		if not gun_owned: SaveManager.add_purchased("guns", current_gun_idx)
		if not color_owned: SaveManager.add_purchased("colors", current_color_idx)

		SaveManager.set_player_stat("body_type", current_body_idx)
		SaveManager.set_player_stat("gun_type", current_gun_idx)
		SaveManager.set_player_stat("color_type", current_color_idx)

		SaveManager.save_game()
		update_ui()

func _on_gun_left_pressed():
	current_gun_idx = (current_gun_idx - 1 + guns.size()) % guns.size()
	update_ui()

func _on_gun_right_pressed():
	current_gun_idx = (current_gun_idx + 1) % guns.size()
	update_ui()

func _on_hull_left_pressed():
	current_body_idx = (current_body_idx - 1 + bodies.size()) % bodies.size()
	update_ui()

func _on_hull_right_pressed():
	current_body_idx = (current_body_idx + 1) % bodies.size()
	update_ui()

func _on_color_left_pressed():
	current_color_idx = (current_color_idx - 1 + colors.size()) % colors.size()
	update_ui()

func _on_color_right_pressed():
	current_color_idx = (current_color_idx + 1) % colors.size()
	update_ui()

func _on_back_button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
