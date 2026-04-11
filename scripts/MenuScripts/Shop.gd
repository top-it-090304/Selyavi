extends Control

@onready var tank_preview_body = find_child("Body", true)
@onready var tank_preview_gun = find_child("Gun", true)
@onready var money_label = find_child("MoneyLabel", true)

@onready var damage_label = find_child("Damage", true)
@onready var hp_label = find_child("HP", true)
@onready var speed_label = find_child("Speed", true)
@onready var rof_label = find_child("ROF", true)
@onready var armor_label = find_child("Armor", true)

@onready var buy_gun_btn = find_child("BuyGun", true)
@onready var buy_hull_btn = find_child("BuyHull", true)
@onready var buy_color_btn = find_child("BuyColor", true)

@onready var color_fill = find_child("Fill", true)

# Item Data - Изменяйте значения "armor" здесь (в процентах)
var bodies = [
	{"id": 0, "name": "Легкий корпус", "price": 25000, "hp": 80, "speed": 280, "armor": -15, "file": "Hull_05", "offset": -15},
	{"id": 1, "name": "Средний корпус", "price": 0, "hp": 100, "speed": 250, "armor": 0, "file": "Hull_02", "offset": -20},
	{"id": 2, "name": "Тяжелый корпус", "price": 5000, "hp": 250, "speed": 200, "armor": 30, "file": "Hull_06", "offset": -15},
	{"id": 3, "name": "Облегченный корпус", "price": 7500, "hp": 120, "speed": 260, "armor": 10, "file": "Hull_01", "offset": -5},
	{"id": 4, "name": "Утяжеленный корпус", "price": 12000, "hp": 175, "speed": 220, "armor": 20, "file": "Hull_03", "offset": -10}
]

var guns = [
	{"id": 0, "name": "Легкая пушка", "price": 20000, "dmg_mod": 0.7, "rof": 0.65, "file": "Gun_01"},
	{"id": 1, "name": "Средняя пушка", "price": 0, "dmg_mod": 1.0, "rof": 1.0, "file": "Gun_03"},
	{"id": 2, "name": "Тяжелая пушка", "price": 4000, "dmg_mod": 2.5, "rof": 1.8, "file": "Gun_08"},
	{"id": 3, "name": "Облегченная пушка", "price": 9000, "dmg_mod": 1.15, "rof": 0.9, "file": "Gun_04"},
	{"id": 4, "name": "Утяжеленная пушка", "price": 11000, "dmg_mod": 1.3, "rof": 0.8, "file": "Gun_07"}
]

var colors = [
	{"id": 0, "name": "Коричневый", "price": 0, "hp_bonus": 0, "speed_bonus": 0, "armor_bonus": 0, "rof_bonus": 0.0, "folder": "Color_A", "color": Color("a47d6c")},
	{"id": 1, "name": "Зеленый", "price": 4000, "hp_bonus": 30, "speed_bonus": -15, "armor_bonus": 10, "rof_bonus": 0.1, "folder": "Color_B", "color": Color("888456")},
	{"id": 2, "name": "Лазурный", "price": 8000, "hp_bonus": 5, "speed_bonus": 30, "armor_bonus": -10, "rof_bonus": 0.05, "folder": "Color_C", "color": Color("699f9c")}
]

var current_body_idx = 0
var current_gun_idx = 0
var current_color_idx = 0

var money = 0

func _ready():
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_menu()

	current_body_idx = SaveManager.get_player_stat("body_type", 1)
	current_gun_idx = SaveManager.get_player_stat("gun_type", 1)
	current_color_idx = SaveManager.get_player_stat("color_type", 0)

	if SaveManager.has_method("_get_money_from_active_player"):
		var m = SaveManager._get_money_from_active_player()
		if m != -1: money = m
		else: money = SaveManager.save_data.get("money", 0)
	else:
		money = SaveManager.save_data.get("money", 0)

	update_ui()

func update_ui():
	if money_label == null: return
	money_label.text = str(int(money))

	var body = bodies[current_body_idx]
	var gun = guns[current_gun_idx]
	var color = colors[current_color_idx]

	var body_path = "res://assets/future_tanks/PNG/Hulls_" + color.folder + "/" + body.file + ".png"
	var gun_path = "res://assets/future_tanks/PNG/Weapon_" + color.folder + "/" + gun.file + ".png"

	var body_tex = load(body_path)
	var gun_tex = load(gun_path)

	if tank_preview_body: tank_preview_body.texture = body_tex
	if tank_preview_gun: tank_preview_gun.texture = gun_tex
	if tank_preview_gun: tank_preview_gun.position = Vector2(0, body.offset)

	if damage_label: damage_label.text = "УРОН: x" + str(gun.dmg_mod)
	if hp_label: hp_label.text = "ЗДОРОВЬЕ: " + str(body.hp + color.hp_bonus)
	if speed_label: speed_label.text = "СКОРОСТЬ: " + str(body.speed + color.speed_bonus)
	if rof_label: rof_label.text = "ПЕРЕЗАРЯДКА: " + str(gun.rof + color.rof_bonus) + " сек"

	# Общее значение брони для отображения
	var total_armor = body.armor + color.armor_bonus
	if armor_label: armor_label.text = "БРОНЯ: " + str(total_armor) + "%"

	var gun_icon = find_child("GunSelector", true).find_child("Icon", true)
	var gun_name = find_child("GunSelector", true).find_child("Label", true)
	if gun_icon: gun_icon.texture = gun_tex
	if gun_name: gun_name.text = gun.name

	var hull_icon = find_child("HullSelector", true).find_child("Icon", true)
	var hull_name = find_child("HullSelector", true).find_child("Label", true)
	if hull_icon: hull_icon.texture = body_tex
	if hull_name: hull_name.text = body.name

	if color_fill:
		var stylebox = color_fill.get_theme_stylebox("panel").duplicate()
		if stylebox is StyleBoxFlat:
			stylebox.bg_color = color.color
			color_fill.add_theme_stylebox_override("panel", stylebox)

	var color_name = find_child("ColorSelector", true).find_child("Label", true)
	if color_name: color_name.text = color.name

	_update_selector_buttons()

func _update_selector_buttons():
	if buy_gun_btn: _update_btn(buy_gun_btn, "guns", current_gun_idx, guns[current_gun_idx].price, "gun_type")
	if buy_hull_btn: _update_btn(buy_hull_btn, "bodies", current_body_idx, bodies[current_body_idx].price, "body_type")
	if buy_color_btn: _update_btn(buy_color_btn, "colors", current_color_idx, colors[current_color_idx].price, "color_type")

func _update_btn(btn: Button, category: String, id: int, price: int, stat_name: String):
	var owned = SaveManager.is_purchased(category, id)
	if price == 0: owned = true
	if owned:
		var equipped = SaveManager.get_player_stat(stat_name, -1) == id
		btn.text = "ВЫБРАНО" if equipped else "ВЫБРАТЬ"
		btn.disabled = equipped
	else:
		btn.text = str(price)
		btn.disabled = (money < price)

func _handle_buy(category: String, id: int, price: int, stat_name: String):
	var owned = SaveManager.is_purchased(category, id)
	if price == 0: owned = true
	if owned:
		SaveManager.set_player_stat(stat_name, id)
		SaveManager.save_game()
	elif money >= price:
		money -= price
		SaveManager.save_data["money"] = money
		SaveManager.add_purchased(category, id)
		SaveManager.set_player_stat(stat_name, id)
		SaveManager.save_game()
	update_ui()

func _on_buy_gun_pressed(): _handle_buy("guns", current_gun_idx, guns[current_gun_idx].price, "gun_type")
func _on_buy_hull_pressed(): _handle_buy("bodies", current_body_idx, bodies[current_body_idx].price, "body_type")
func _on_buy_color_pressed(): _handle_buy("colors", current_color_idx, colors[current_color_idx].price, "color_type")

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
