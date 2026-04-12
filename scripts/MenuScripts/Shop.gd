extends Control

@onready var tank_preview_body = find_child("Body", true)
@onready var tank_preview_gun = find_child("Gun", true)
@onready var base_preview = find_child("BasePreview", true)
@onready var money_label = find_child("MoneyLabel", true)

@onready var tank_stats = find_child("TankStats", true)
@onready var base_stats = find_child("BaseStats", true)

@onready var damage_label = find_child("Damage", true)
@onready var hp_label = find_child("HP", true)
@onready var speed_label = find_child("Speed", true)
@onready var rof_label = find_child("ROF", true)
@onready var armor_label = find_child("Armor", true)

@onready var base_hp_label = find_child("BaseHP", true)
@onready var base_heal_label = find_child("BaseHeal", true)
@onready var base_bonus_label = find_child("BaseBonus", true)
@onready var base_feature_label = find_child("BaseFeature", true)

@onready var buy_gun_btn = find_child("BuyGun", true)
@onready var buy_hull_btn = find_child("BuyHull", true)
@onready var buy_color_btn = find_child("BuyColor", true)

@onready var tank_selectors = find_child("TankSelectors", true)
@onready var base_selectors = find_child("BaseSelectors", true)

@onready var tank_tab_btn = find_child("TankTab", true)
@onready var base_tab_btn = find_child("BaseTab", true)

@onready var color_fill = find_child("Fill", true)

@onready var feature_desc_label = find_child("FeatureDesc", true)

# Item Data - Tank
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

# Item Data - Base
var base_hps = [
	{"id": 0, "name": "Деревянные баррикады", "price": 0, "hp": 150},
	{"id": 1, "name": "Стальные пластины", "price": 3000, "hp": 200},
	{"id": 2, "name": "Бетонный бункер", "price": 7000, "hp": 250},
	{"id": 3, "name": "Титановая защита", "price": 15000, "hp": 350}
]

var base_heals = [
	{"id": 0, "name": "Полевой ремонт", "price": 0, "heal": 5},
	{"id": 1, "name": "Новые ремкомплеткы", "price": 4000, "heal": 7},
	{"id": 2, "name": "Элитные механики", "price": 10000, "heal": 10}
]

var base_bonuses = [
	{"id": 0, "name": "Боевой дух", "price": 0, "bonus": 1.1},
	{"id": 1, "name": "Ни шагу назад!", "price": 5000, "bonus": 1.3},
	{"id": 2, "name": "Элитная подготовка", "price": 12000, "bonus": 1.5}
]

var base_features = [
	{"id": 0, "name": "Ничего", "price": 0, "desc": "Стандартная конфигурация штаба без дополнительных модулей."},
	{"id": 1, "name": "Радар", "price": 6000, "desc": "Разведданные в реальном времени. Штабы врага всегда видны на карте."},
	{"id": 2, "name": "Автономная турель", "price": 15000, "desc": "Автоматическая система обороны. Штаб может давать отпор наступающим врагам."},
	{"id": 3, "name": "Био-Осмос", "price": 25000, "desc": "Передовые технологии восстановления. Штаб начинает медленно чиниться сам со временем."}
]

var current_body_idx = 0
var current_gun_idx = 0
var current_color_idx = 0

var current_base_hp_idx = 0
var current_base_heal_idx = 0
var current_base_bonus_idx = 0
var current_base_feature_idx = 0

var current_tab = "tank"

var money = 0

func _ready():
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_menu()

	_load_stats()
	_switch_tab("tank")
	update_ui()

func _load_stats():
	current_body_idx = SaveManager.get_player_stat("body_type", 1)
	current_gun_idx = SaveManager.get_player_stat("gun_type", 1)
	current_color_idx = SaveManager.get_player_stat("color_type", 0)

	current_base_hp_idx = SaveManager.get_player_stat("base_hp_level", 0)
	current_base_heal_idx = SaveManager.get_player_stat("base_heal_level", 0)
	current_base_bonus_idx = SaveManager.get_player_stat("base_bonus_level", 0)
	current_base_feature_idx = SaveManager.get_player_stat("base_feature_type", 0)

	if SaveManager.has_method("_get_money_from_active_player"):
		var m = SaveManager._get_money_from_active_player()
		if m != -1: money = m
		else: money = SaveManager.save_data.get("money", 0)
	else:
		money = SaveManager.save_data.get("money", 0)

func update_ui():
	if money_label == null: return
	money_label.text = str(int(money))

	if current_tab == "tank":
		_update_tank_ui()
	else:
		_update_base_ui()

func _update_tank_ui():
	var body = bodies[current_body_idx]
	var gun = guns[current_gun_idx]
	var color = colors[current_color_idx]

	var body_path = "res://assets/future_tanks/PNG/Hulls_" + color.folder + "/" + body.file + ".png"
	var gun_path = "res://assets/future_tanks/PNG/Weapon_" + color.folder + "/" + gun.file + ".png"

	if tank_preview_body: tank_preview_body.texture = load(body_path)
	if tank_preview_gun: tank_preview_gun.texture = load(gun_path)
	if tank_preview_gun: tank_preview_gun.position = Vector2(0, body.offset)

	if damage_label: damage_label.text = "УРОН: x" + str(gun.dmg_mod)
	if hp_label: hp_label.text = "ЗДОРОВЬЕ: " + str(body.hp + color.hp_bonus)
	if speed_label: speed_label.text = "СКОРОСТЬ: " + str(body.speed + color.speed_bonus)
	if rof_label: rof_label.text = "ПЕРЕЗАРЯДКА: " + str(gun.rof + color.rof_bonus) + " сек"
	var total_armor = body.armor + color.armor_bonus
	if armor_label: armor_label.text = "БРОНЯ: " + str(total_armor) + "%"

	_update_selector_label("GunSelector", gun.name, load(gun_path))
	_update_selector_label("HullSelector", body.name, load(body_path))

	if color_fill:
		var stylebox = color_fill.get_theme_stylebox("panel").duplicate()
		stylebox.bg_color = color.color
		color_fill.add_theme_stylebox_override("panel", stylebox)
	_update_selector_label("ColorSelector", color.name, null)

	_update_btn(buy_gun_btn, "guns", current_gun_idx, guns[current_gun_idx].price, "gun_type")
	_update_btn(buy_hull_btn, "bodies", current_body_idx, bodies[current_body_idx].price, "body_type")
	_update_btn(buy_color_btn, "colors", current_color_idx, colors[current_color_idx].price, "color_type")

func _update_base_ui():
	var hp_data = base_hps[current_base_hp_idx]
	var heal_data = base_heals[current_base_heal_idx]
	var bonus_data = base_bonuses[current_base_bonus_idx]
	var feature_data = base_features[current_base_feature_idx]

	if base_hp_label: base_hp_label.text = "ПРОЧНОСТЬ: " + str(hp_data.hp)
	if base_heal_label: base_heal_label.text = "РЕМОНТ: " + str(heal_data.heal) + " HP/сек"
	if base_bonus_label: base_bonus_label.text = "БОНУС УРОНА: x" + str(bonus_data.bonus)

	# Слева оставляем только название
	if base_feature_label: base_feature_label.text = "ИННОВАЦИЯ: " + feature_data.name

	# Под селектором показываем описание
	if feature_desc_label: feature_desc_label.text = feature_data.desc

	_update_selector_label("HPSelector", hp_data.name, null)
	_update_selector_label("HealSelector", heal_data.name, null)
	_update_selector_label("BonusSelector", bonus_data.name, null)
	_update_selector_label("FeatureSelector", feature_data.name, null)

	_update_btn(find_child("BuyBaseHP", true), "base_hp", current_base_hp_idx, hp_data.price, "base_hp_level")
	_update_btn(find_child("BuyBaseHeal", true), "base_heal", current_base_heal_idx, heal_data.price, "base_heal_level")
	_update_btn(find_child("BuyBaseBonus", true), "base_bonus", current_base_bonus_idx, bonus_data.price, "base_bonus_level")
	_update_btn(find_child("BuyBaseFeature", true), "base_features", current_base_feature_idx, feature_data.price, "base_feature_type")

func _update_selector_label(node_name, text, icon_tex):
	var node = find_child(node_name, true)
	if !node: return
	var label = node.find_child("Label", true)
	if label: label.text = text
	var icon = node.find_child("Icon", true)
	if icon and icon_tex: icon.texture = icon_tex

func _update_btn(btn: Button, category: String, id: int, price: int, stat_name: String):
	if !btn: return
	var owned = SaveManager.is_purchased(category, id)
	if price == 0: owned = true
	if owned:
		var equipped = SaveManager.get_player_stat(stat_name, -1) == id
		btn.text = "ВЫБРАНО" if equipped else "ВЫБРАТЬ"
		btn.disabled = equipped
	else:
		btn.text = str(price)
		btn.disabled = (money < price)

func _switch_tab(tab_name: String):
	current_tab = tab_name
	var active_style = load("res://scenes/MenuScenes/Shop.tscn::StyleBoxFlat_tab_active")
	var inactive_style = load("res://scenes/MenuScenes/Shop.tscn::StyleBoxFlat_tab_inactive")

	if tab_name == "tank":
		tank_tab_btn.add_theme_stylebox_override("normal", active_style)
		base_tab_btn.add_theme_stylebox_override("normal", inactive_style)
		tank_preview_body.visible = true
		tank_preview_gun.visible = true
		base_preview.visible = false
		tank_stats.visible = true
		base_stats.visible = false
		tank_selectors.visible = true
		base_selectors.visible = false
	else:
		tank_tab_btn.add_theme_stylebox_override("normal", inactive_style)
		base_tab_btn.add_theme_stylebox_override("normal", active_style)
		tank_preview_body.visible = false
		tank_preview_gun.visible = false
		base_preview.visible = true
		tank_stats.visible = false
		base_stats.visible = true
		tank_selectors.visible = false
		base_selectors.visible = true
	update_ui()

func _on_tank_tab_pressed(): _switch_tab("tank")
func _on_base_tab_pressed(): _switch_tab("base")

func _handle_buy(category: String, id: int, price: int, stat_name: String):
	var owned = SaveManager.is_purchased(category, id)
	if price == 0: owned = true
	if owned:
		SaveManager.set_player_stat(stat_name, id)
	elif money >= price:
		money -= price
		SaveManager.save_data["money"] = money
		SaveManager.add_purchased(category, id)
		SaveManager.set_player_stat(stat_name, id)
	SaveManager.save_game()
	update_ui()

# Танк - сигналы
func _on_buy_gun_pressed(): _handle_buy("guns", current_gun_idx, guns[current_gun_idx].price, "gun_type")
func _on_buy_hull_pressed(): _handle_buy("bodies", current_body_idx, bodies[current_body_idx].price, "body_type")
func _on_buy_color_pressed(): _handle_buy("colors", current_color_idx, colors[current_color_idx].price, "color_type")
func _on_gun_left_pressed(): current_gun_idx = (current_gun_idx - 1 + guns.size()) % guns.size(); update_ui()
func _on_gun_right_pressed(): current_gun_idx = (current_gun_idx + 1) % guns.size(); update_ui()
func _on_hull_left_pressed(): current_body_idx = (current_body_idx - 1 + bodies.size()) % bodies.size(); update_ui()
func _on_hull_right_pressed(): current_body_idx = (current_body_idx + 1) % bodies.size(); update_ui()
func _on_color_left_pressed(): current_color_idx = (current_color_idx - 1 + colors.size()) % colors.size(); update_ui()
func _on_color_right_pressed(): current_color_idx = (current_color_idx + 1) % colors.size(); update_ui()

# Штаб - сигналы
func _on_buy_base_hp_pressed(): _handle_buy("base_hp", current_base_hp_idx, base_hps[current_base_hp_idx].price, "base_hp_level")
func _on_buy_base_heal_pressed(): _handle_buy("base_heal", current_base_heal_idx, base_heals[current_base_heal_idx].price, "base_heal_level")
func _on_buy_base_bonus_pressed(): _handle_buy("base_bonus", current_base_bonus_idx, base_bonuses[current_base_bonus_idx].price, "base_bonus_level")
func _on_buy_base_feature_pressed(): _handle_buy("base_features", current_base_feature_idx, base_features[current_base_feature_idx].price, "base_feature_type")
func _on_base_hp_left_pressed(): current_base_hp_idx = (current_base_hp_idx - 1 + base_hps.size()) % base_hps.size(); update_ui()
func _on_base_hp_right_pressed(): current_base_hp_idx = (current_base_hp_idx + 1) % base_hps.size(); update_ui()
func _on_base_heal_left_pressed(): current_base_heal_idx = (current_base_heal_idx - 1 + base_heals.size()) % base_heals.size(); update_ui()
func _on_base_heal_right_pressed(): current_base_heal_idx = (current_base_heal_idx + 1) % base_heals.size(); update_ui()
func _on_base_bonus_left_pressed(): current_base_bonus_idx = (current_base_bonus_idx - 1 + base_bonuses.size()) % base_bonuses.size(); update_ui()
func _on_base_bonus_right_pressed(): current_base_bonus_idx = (current_base_bonus_idx + 1) % base_bonuses.size(); update_ui()
func _on_base_feature_left_pressed(): current_base_feature_idx = (current_base_feature_idx - 1 + base_features.size()) % base_features.size(); update_ui()
func _on_base_feature_right_pressed(): current_base_feature_idx = (current_base_feature_idx + 1) % base_features.size(); update_ui()

func _on_back_button_pressed(): get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
