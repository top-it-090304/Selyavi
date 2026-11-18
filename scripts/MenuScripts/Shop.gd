extends Control

@onready var tank_preview_body = find_child("Body", true)
@onready var tank_preview_gun = find_child("Gun", true)
@onready var base_preview = find_child("BasePreview", true)
@onready var antenna_preview = find_child("Antenna", true)
@onready var turret_preview = find_child("Turret", true)
@onready var artifact_preview = find_child("Artifact", true)
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
@onready var buy_ammo_btn = find_child("BuyAmmo", true)
var equip_ammo_btn = null

# Прямые ссылки на динамически создаваемые узлы амmo-таба
var _ammo_preview_icon: TextureRect = null
var _ammo_preview_name: Label = null
var _ammo_desc_label: Label = null
var _ammo_price_label: Label
var _ammo_stats_label: Label
var _ammo_page: VBoxContainer
var _ammo_catalog_buttons: Array[Button] = []
var _ammo_assign_row: HBoxContainer
var _slot_panels: Array = []
var _slot_icons: Array = []
var _slot_names: Array = []
var _slot_equip_btns: Array = []

@onready var tank_selectors = find_child("TankSelectors", true)
@onready var base_selectors = find_child("BaseSelectors", true)
@onready var ammo_selectors = find_child("AmmoSelectors", true)

@onready var tank_tab_btn = find_child("TankTab", true)
@onready var base_tab_btn = find_child("BaseTab", true)
@onready var ammo_tab_btn = find_child("AmmoTab", true)
@onready var tank_frame = find_child("TankFrame", true)

## Слоты снарядов слева (вместо превью танка на вкладке «Снаряды»)
var _ammo_left_slots_root: VBoxContainer = null
var _ammo_left_margin: MarginContainer = null

@onready var color_fill = find_child("Fill", true)

@onready var feature_desc_label = find_child("FeatureDesc", true)

# Item Data - Tank
var bodies = [
	{"id": 0, "name": "Легкий корпус", "price": 4000, "hp": 110, "speed": 280, "armor": -15, "file": "Hull_05", "offset": -15},
	{"id": 1, "name": "Средний корпус", "price": 0, "hp": 100, "speed": 250, "armor": 0, "file": "Hull_02", "offset": -20},
	{"id": 2, "name": "Тяжелый корпус", "price": 6000, "hp": 200, "speed": 180, "armor": 30, "file": "Hull_06", "offset": -15},
	{"id": 3, "name": "Облегченный корпус", "price": 4200, "hp": 120, "speed": 260, "armor": 10, "file": "Hull_01", "offset": -5},
	{"id": 4, "name": "Утяжеленный корпус", "price": 6000, "hp": 175, "speed": 220, "armor": 20, "file": "Hull_03", "offset": -10}
]

var guns = [
	{"id": 0, "name": "Легкая пушка", "price": 7000, "dmg_mod": 0.7, "rof": 0.65, "file": "Gun_01"},
	{"id": 1, "name": "Средняя пушка", "price": 0, "dmg_mod": 1.0, "rof": 1.0, "file": "Gun_03"},
	{"id": 2, "name": "Тяжелая пушка", "price": 2000, "dmg_mod": 3.0, "rof": 1.8, "file": "Gun_08"},
	{"id": 3, "name": "Облегченная пушка", "price": 4500, "dmg_mod": 1.15, "rof": 0.75, "file": "Gun_04"},
	{"id": 4, "name": "Утяжеленная пушка", "price": 5500, "dmg_mod": 1.6, "rof": 1.0, "file": "Gun_07"}
]

var colors = [
	{"id": 0, "name": "Коричневый", "price": 0, "hp_bonus": 0, "speed_bonus": 0, "armor_bonus": 0, "rof_bonus": 0.0, "folder": "Color_A", "color": Color("a47d6c")},
	{"id": 1, "name": "Зеленый", "price": 2000, "hp_bonus": 30, "speed_bonus": -15, "armor_bonus": 10, "rof_bonus": 0.1, "folder": "Color_B", "color": Color("888456")},
	{"id": 2, "name": "Лазурный", "price": 4000, "hp_bonus": 5, "speed_bonus": 30, "armor_bonus": -10, "rof_bonus": 0.05, "folder": "Color_C", "color": Color("699f9c")}
]

var ammo_types = [
	{"id": 0, "name": "Плазма", "price": 0, "desc": "Сбалансированный плазменный снаряд со средней дальностью.", "icon": "res://assets/future_tanks/PNG/Effects/Plasma.png"},
	{"id": 1, "name": "Средний", "price": 0, "desc": "Тяжелее и мощнее: выше урон, но короче дистанция.", "icon": "res://assets/future_tanks/PNG/Effects/Medium_Shell.png"},
	{"id": 2, "name": "Легкий", "price": 0, "desc": "Быстрый и дальнобойный снаряд с меньшим уроном.", "icon": "res://assets/future_tanks/PNG/Effects/Light_Shell.png"},
	{"id": 3, "name": "Фугас", "price": 3000, "desc": "Взрывной снаряд: наносит урон по площади вокруг точки попадания.", "icon": "res://assets/future_tanks/PNG/Effects/Granade_Shell.png"},
	{"id": 4, "name": "БОПС", "price": 4500, "desc": "Бронебойный оперенный снаряд: пробивает не более двух танков по одной линии.", "icon": "res://assets/future_tanks/PNG/Effects/Heavy_Shell.png"},
	{"id": 5, "name": "Рикошет", "price": 3750, "desc": "Снаряд отскакивает от стен до двух раз. При каждом рикошете урон увеличивается на 6. Не взрывается.", "icon": "res://assets/future_tanks/PNG/Effects/Laser.png"}
]

# Item Data - Base
var base_hps = [
	{"id": 0, "name": "Деревянные баррикады", "price": 0, "hp": 150},
	{"id": 1, "name": "Стальные пластины", "price": 1500, "hp": 200},
	{"id": 2, "name": "Бетонный бункер", "price": 3500, "hp": 250},
	{"id": 3, "name": "Титановая защита", "price": 5000, "hp": 350}
]

var base_heals = [
	{"id": 0, "name": "Полевой ремонт", "price": 0, "heal": 5},
	{"id": 1, "name": "Новые ремкомплеткы", "price": 2000, "heal": 7},
	{"id": 2, "name": "Элитные механики", "price": 5000, "heal": 10}
]

var base_bonuses = [
	{"id": 0, "name": "Боевой дух", "price": 0, "bonus": 1.1},
	{"id": 1, "name": "Ни шагу назад!", "price": 5000, "bonus": 1.3},
	{"id": 2, "name": "Элитная подготовка", "price": 7000, "bonus": 1.5}
]

var base_features = [
	{"id": 0, "name": "Ничего", "price": 0, "desc": "Стандартная конфигурация штаба без дополнительных модулей."},
	{"id": 1, "name": "Радар", "price": 3000, "desc": "Разведданные в реальном времени. Штабы врага всегда видны на карте."},
	{"id": 2, "name": "Автономная турель", "price": 15000, "desc": "Автоматическая система обороны. Штаб может давать отпор наступающим врагам."},
	{"id": 3, "name": "Био-Осмос", "price": 13000, "desc": "Передовые технологии восстановления. Штаб начинает медленно чиниться сам со временем."}
]

var current_body_idx = 0
var current_gun_idx = 0
var current_color_idx = 0
var current_ammo_idx = 0
var ammo_loadout_slots = [2, 0, 1]

var current_base_hp_idx = 0
var current_base_heal_idx = 0
var current_base_bonus_idx = 0
var current_base_feature_idx = 0

var current_tab = "tank"

var money = 0
# Display distances and speeds in the same game-world units.
const PIXELS_PER_SHOP_UNIT := 60.0
const SHOP_FONT_PATH := "res://assets/fonts/ofont.ru_Shonen.ttf"

func _ready():
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_menu()

	_load_stats()
	_setup_ammo_tab()
	_switch_tab("tank")
	update_ui()

func _load_stats():
	current_body_idx = SaveManager.get_player_stat("body_type", 1)
	current_gun_idx = SaveManager.get_player_stat("gun_type", 1)
	current_color_idx = SaveManager.get_player_stat("color_type", 0)
	ammo_loadout_slots[0] = SaveManager.get_player_stat("ammo_slot_0", 2)
	ammo_loadout_slots[1] = SaveManager.get_player_stat("ammo_slot_1", 0)
	ammo_loadout_slots[2] = SaveManager.get_player_stat("ammo_slot_2", 1)
	current_ammo_idx = ammo_loadout_slots[0]

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
	elif current_tab == "ammo":
		_update_ammo_ui()
	else:
		_update_base_ui()

func _setup_ammo_tab():
	var tabs = find_child("Tabs", true) as HBoxContainer
	if tabs and ammo_tab_btn == null:
		tabs.offset_left = -430.0
		tabs.offset_right = 430.0
		var tab_btn = Button.new()
		tab_btn.name = "AmmoTab"
		tab_btn.custom_minimum_size = Vector2(250, 0)
		tab_btn.focus_mode = Control.FOCUS_NONE
		tab_btn.text = "СНАРЯДЫ"
		tab_btn.add_theme_font_override("font", load(SHOP_FONT_PATH))
		tab_btn.add_theme_font_size_override("font_size", 28)
		tab_btn.add_theme_stylebox_override("focus", load("res://scenes/MenuScenes/Shop.tscn::StyleBoxEmpty_focus"))
		tab_btn.add_theme_stylebox_override("hover", load("res://scenes/MenuScenes/Shop.tscn::StyleBoxFlat_tab_active"))
		tab_btn.add_theme_stylebox_override("pressed", load("res://scenes/MenuScenes/Shop.tscn::StyleBoxFlat_tab_active"))
		tab_btn.add_theme_stylebox_override("normal", load("res://scenes/MenuScenes/Shop.tscn::StyleBoxFlat_tab_inactive"))
		tabs.add_child(tab_btn)
		tab_btn.pressed.connect(_on_ammo_tab_pressed)
		ammo_tab_btn = tab_btn

	_ammo_page = VBoxContainer.new()
	_ammo_page.name = "AmmoPage"
	_ammo_page.visible = false
	_ammo_page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_ammo_page.anchor_left = 0.07
	_ammo_page.anchor_top = 0.29
	_ammo_page.anchor_right = 0.95
	_ammo_page.anchor_bottom = 0.94
	_ammo_page.add_theme_constant_override("separation", 12)
	add_child(_ammo_page)
	var columns = HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 24)
	_ammo_page.add_child(columns)
	var catalog_scroll = preload("res://scripts/MenuScripts/ShopSwipeScroll.gd").new()
	catalog_scroll.name = "AmmoCatalogScroll"
	catalog_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	catalog_scroll.custom_minimum_size.x = 360
	catalog_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	columns.add_child(catalog_scroll)
	var catalog = VBoxContainer.new()
	catalog.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	catalog.add_theme_constant_override("separation", 8)
	catalog_scroll.add_child(catalog)
	catalog.add_child(_ammo_label("СНАРЯДЫ", 22))
	for i in range(ammo_types.size()):
		var button = _create_buy_button()
		button.name = "AmmoItem" + str(i)
		button.text = ""
		button.custom_minimum_size = Vector2(0, 130)
		var row = HBoxContainer.new()
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		row.offset_left = 10
		row.offset_top = 10
		row.offset_right = -10
		row.offset_bottom = -10
		row.add_theme_constant_override("separation", 12)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(row)
		var preview = TextureRect.new()
		# Same 110 × 110 texture area as the original 130px preview with 10px padding.
		preview.custom_minimum_size = Vector2(110, 110)
		preview.texture = load(ammo_types[i].icon)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(preview)
		var title = _ammo_label(ammo_types[i].name, 24)
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(title)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.pressed.connect(func():
			if not catalog_scroll.can_select_item():
				return
			current_ammo_idx = i
			_ammo_assign_row.visible = false
			update_ui()
		)
		catalog.add_child(button)
		_ammo_catalog_buttons.append(button)
	var detail_scroll = preload("res://scripts/MenuScripts/ShopSwipeScroll.gd").new()
	detail_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.add_theme_stylebox_override("panel", load("res://scenes/MenuScenes/Shop.tscn::StyleBoxFlat_scroll_bg"))
	columns.add_child(detail_scroll)
	var details = VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 12)
	detail_scroll.add_child(details)
	_ammo_preview_name = _ammo_label("", 28)
	details.add_child(_ammo_preview_name)
	_ammo_desc_label = _ammo_label("", 19)
	details.add_child(_ammo_desc_label)
	_ammo_stats_label = _ammo_label("", 20)
	details.add_child(_ammo_stats_label)
	_ammo_price_label = _ammo_label("", 20)
	details.add_child(_ammo_price_label)
	var actions = HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	details.add_child(actions)
	buy_ammo_btn = _create_buy_button()
	buy_ammo_btn.pressed.connect(_on_buy_ammo_pressed)
	actions.add_child(buy_ammo_btn)
	equip_ammo_btn = _create_buy_button()
	equip_ammo_btn.text = "ПОСТАВИТЬ В СЛОТ"
	equip_ammo_btn.add_theme_font_size_override("font_size", 20)
	equip_ammo_btn.pressed.connect(func(): _ammo_assign_row.visible = not _ammo_assign_row.visible)
	actions.add_child(equip_ammo_btn)
	_ammo_assign_row = HBoxContainer.new()
	_ammo_assign_row.visible = false
	_ammo_assign_row.add_theme_constant_override("separation", 8)
	details.add_child(_ammo_assign_row)
	for i in range(3):
		var assign = _create_buy_button()
		assign.custom_minimum_size = Vector2(0, 80)
		assign.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		assign.add_theme_font_size_override("font_size", 26)
		assign.text = "СЛОТ " + str(i + 1)
		assign.pressed.connect(func():
			if not detail_scroll.can_select_item():
				return
			_on_equip_to_slot(i)
			_ammo_assign_row.visible = false
		)
		_ammo_assign_row.add_child(assign)
	var bottom = HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 16)
	_ammo_page.add_child(bottom)
	var loadout_title = _ammo_label("ВАШ\nБОЕЗАПАС", 20)
	loadout_title.custom_minimum_size.x = 150
	loadout_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	bottom.add_child(loadout_title)
	for i in range(3):
		var panel = PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", load("res://scenes/MenuScenes/Shop.tscn::StyleBoxFlat_scroll_bg"))
		bottom.add_child(panel)
		var row = HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		panel.add_child(row)
		var icon = TextureRect.new()
		icon.custom_minimum_size = Vector2(80, 80)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)
		_slot_icons.append(icon)
		var name_label = _ammo_label("", 18)
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)
		_slot_names.append(name_label)

func _ammo_label(value: String, font_size: int) -> Label:
	var label = Label.new()
	label.text = value
	label.add_theme_font_override("font", load(SHOP_FONT_PATH))
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(0.741176, 0.819608, 0.705882, 1))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _create_selector_button(text_value: String) -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(70, 70)
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = text_value
	btn.add_theme_font_override("font", load(SHOP_FONT_PATH))
	btn.add_theme_font_size_override("font_size", 40)
	btn.add_theme_stylebox_override("focus", load("res://scenes/MenuScenes/Shop.tscn::StyleBoxEmpty_focus"))
	btn.add_theme_stylebox_override("hover", load("res://scenes/MenuScenes/Shop.tscn::StyleBoxFlat_btn_hover"))
	btn.add_theme_stylebox_override("pressed", load("res://scenes/MenuScenes/Shop.tscn::StyleBoxFlat_btn_pressed"))
	btn.add_theme_stylebox_override("normal", load("res://scenes/MenuScenes/Shop.tscn::StyleBoxFlat_btn_normal"))
	return btn

func _create_buy_button() -> Button:
	var btn = Button.new()
	btn.custom_minimum_size = Vector2(180, 70)
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = "КУПИТЬ"
	btn.add_theme_font_override("font", load(SHOP_FONT_PATH))
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_stylebox_override("focus", load("res://scenes/MenuScenes/Shop.tscn::StyleBoxEmpty_focus"))
	btn.add_theme_stylebox_override("hover", load("res://scenes/MenuScenes/Shop.tscn::StyleBoxFlat_btn_hover"))
	btn.add_theme_stylebox_override("pressed", load("res://scenes/MenuScenes/Shop.tscn::StyleBoxFlat_btn_pressed"))
	btn.add_theme_stylebox_override("normal", load("res://scenes/MenuScenes/Shop.tscn::StyleBoxFlat_btn_normal"))
	return btn

func _update_ammo_ui():
	var ammo_data = ammo_types[current_ammo_idx]
	var tex = load(ammo_data.icon)

	# Превью просматриваемого снаряда
	if _ammo_preview_icon:
		_ammo_preview_icon.texture = tex
	if _ammo_preview_name:
		_ammo_preview_name.text = ammo_data.name
	if _ammo_desc_label:
		_ammo_desc_label.text = ammo_data.desc

	var damages = [25, 40, 15, 30, 26, 22]
	var ranges = [650, 300, 1000, 550, 1100, 1200]
	var speeds = [540, 240, 420, 300, 480, 540]
	_ammo_stats_label.text = "БАЗОВЫЙ УРОН: %d\nДАЛЬНОСТЬ: %s ед.\nСКОРОСТЬ: %s ед/с" % [damages[current_ammo_idx], String.num(ranges[current_ammo_idx] / PIXELS_PER_SHOP_UNIT, 1), String.num(speeds[current_ammo_idx] / PIXELS_PER_SHOP_UNIT, 1)]
	if current_ammo_idx == 3:
		_ammo_stats_label.text += "\nРАДИУС ВЗРЫВА: %s ед." % String.num(105.0 / PIXELS_PER_SHOP_UNIT, 2)
	elif current_ammo_idx == 4:
		_ammo_stats_label.text += "\nПРОБИТИЕ: ДО 2 ТАНКОВ"
	elif current_ammo_idx == 5:
		_ammo_stats_label.text += "\nРИКОШЕТЫ: 2"
	for i in range(_ammo_catalog_buttons.size()):
		# Preserve the complete button border and dimensions in every state.
		var item_style = load("res://scenes/MenuScenes/Shop.tscn::StyleBoxFlat_btn_normal").duplicate() as StyleBoxFlat
		if i == current_ammo_idx:
			item_style.bg_color = Color(0.290196, 0.341176, 0.25098, 1)
			item_style.border_color = Color(0.439216, 0.501961, 0.380392, 1)
		_ammo_catalog_buttons[i].add_theme_stylebox_override("normal", item_style)

	# Кнопка покупки
	var owned_preview = SaveManager.is_purchased("ammo_types", current_ammo_idx) or ammo_data.price == 0
	_ammo_price_label.visible = not owned_preview
	_ammo_price_label.text = "СТОИМОСТЬ: " + str(ammo_data.price) + " монет"
	if buy_ammo_btn:
		if owned_preview:
			buy_ammo_btn.text = "КУПЛЕНО"
			buy_ammo_btn.disabled = true
		else:
			buy_ammo_btn.text = "КУПИТЬ · " + str(ammo_data.price)
			buy_ammo_btn.disabled = money < ammo_data.price

	equip_ammo_btn.disabled = not owned_preview
	buy_ammo_btn.visible = not owned_preview
	for i in range(3):
		var slot_data = ammo_types[ammo_loadout_slots[i]]
		_slot_icons[i].texture = load(slot_data.icon)
		_slot_names[i].text = "СЛОТ %d\n%s" % [i + 1, slot_data.name]

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

	_update_btn(buy_gun_btn, "guns", current_gun_idx, guns[current_gun_idx].price, "gun_type", 1)
	_update_btn(buy_hull_btn, "bodies", current_body_idx, bodies[current_body_idx].price, "body_type", 1)
	_update_btn(buy_color_btn, "colors", current_color_idx, colors[current_color_idx].price, "color_type", 0)

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

	# Визуализация антенны (радара), турели и артефакта (био-осмоса) на превью
	if antenna_preview: antenna_preview.visible = (current_base_feature_idx == 1)
	if turret_preview: turret_preview.visible = (current_base_feature_idx == 2)
	if artifact_preview: artifact_preview.visible = (current_base_feature_idx == 3)

	_update_selector_label("HPSelector", hp_data.name, null)
	_update_selector_label("HealSelector", heal_data.name, null)
	_update_selector_label("BonusSelector", bonus_data.name, null)
	_update_selector_label("FeatureSelector", feature_data.name, null)

	_update_btn(find_child("BuyBaseHP", true), "base_hp", current_base_hp_idx, hp_data.price, "base_hp_level", 0)
	_update_btn(find_child("BuyBaseHeal", true), "base_heal", current_base_heal_idx, heal_data.price, "base_heal_level", 0)
	_update_btn(find_child("BuyBaseBonus", true), "base_bonus", current_base_bonus_idx, bonus_data.price, "base_bonus_level", 0)
	_update_btn(find_child("BuyBaseFeature", true), "base_features", current_base_feature_idx, feature_data.price, "base_feature_type", 0)

func _update_selector_label(node_name, text, icon_tex):
	var node = find_child(node_name, true)
	if !node: return
	var label = node.find_child("Label", true)
	if label: label.text = text
	var icon = node.find_child("Icon", true)
	if icon and icon_tex: icon.texture = icon_tex

func _update_btn(btn: Button, category: String, id: int, price: int, stat_name: String, default_id: int):
	if !btn: return

	# Проверка владения: либо куплено, либо цена 0 (базовый предмет)
	var owned = SaveManager.is_purchased(category, id) or price == 0

	if owned:
		var equipped = SaveManager.get_player_stat(stat_name, default_id) == id
		btn.text = "ВЫБРАНО" if equipped else "ВЫБРАТЬ"
		btn.disabled = equipped
	else:
		btn.text = str(price)
		btn.disabled = (money < price)

func _switch_tab(tab_name: String):
	current_tab = tab_name
	$Content.visible = tab_name != "ammo"
	_ammo_page.visible = tab_name == "ammo"
	_ammo_assign_row.visible = false
	var active_style = load("res://scenes/MenuScenes/Shop.tscn::StyleBoxFlat_tab_active")
	var inactive_style = load("res://scenes/MenuScenes/Shop.tscn::StyleBoxFlat_tab_inactive")

	if tab_name == "tank":
		tank_tab_btn.add_theme_stylebox_override("normal", active_style)
		base_tab_btn.add_theme_stylebox_override("normal", inactive_style)
		if ammo_tab_btn: ammo_tab_btn.add_theme_stylebox_override("normal", inactive_style)
		if tank_frame: tank_frame.visible = true
		if _ammo_left_margin: _ammo_left_margin.visible = false
		tank_preview_body.visible = true
		tank_preview_gun.visible = true
		base_preview.visible = false
		tank_stats.visible = true
		base_stats.visible = false
		tank_selectors.visible = true
		base_selectors.visible = false
		if ammo_selectors: ammo_selectors.visible = false
	elif tab_name == "ammo":
		tank_tab_btn.add_theme_stylebox_override("normal", inactive_style)
		base_tab_btn.add_theme_stylebox_override("normal", inactive_style)
		if ammo_tab_btn: ammo_tab_btn.add_theme_stylebox_override("normal", active_style)
		if tank_frame: tank_frame.visible = false
		if _ammo_left_margin: _ammo_left_margin.visible = true
		tank_stats.visible = true
		base_stats.visible = false
		tank_selectors.visible = false
		base_selectors.visible = false
		if ammo_selectors: ammo_selectors.visible = true
	else:
		tank_tab_btn.add_theme_stylebox_override("normal", inactive_style)
		base_tab_btn.add_theme_stylebox_override("normal", active_style)
		if ammo_tab_btn: ammo_tab_btn.add_theme_stylebox_override("normal", inactive_style)
		if tank_frame: tank_frame.visible = true
		if _ammo_left_margin: _ammo_left_margin.visible = false
		tank_preview_body.visible = false
		tank_preview_gun.visible = false
		base_preview.visible = true
		tank_stats.visible = false
		base_stats.visible = true
		tank_selectors.visible = false
		base_selectors.visible = true
		if ammo_selectors: ammo_selectors.visible = false
	update_ui()

func _on_tank_tab_pressed(): _switch_tab("tank")
func _on_base_tab_pressed(): _switch_tab("base")
func _on_ammo_tab_pressed(): _switch_tab("ammo")

func _handle_buy(category: String, id: int, price: int, stat_name: String):
	var owned = SaveManager.is_purchased(category, id) or price == 0
	if owned:
		SaveManager.set_player_stat(stat_name, id)
	elif money >= price:
		money -= price
		SaveManager.save_data["money"] = money
		SaveManager.add_purchased(category, id)
		SaveManager.set_player_stat(stat_name, id)
		PycoLog.log_event_by_type("shop_purchase", {"category": category, "id": id, "price": price})
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
func _on_buy_ammo_pressed():
	var price = ammo_types[current_ammo_idx].price
	var owned = SaveManager.is_purchased("ammo_types", current_ammo_idx) or price == 0
	if owned:
		update_ui()
		return
	if money >= price:
		money -= price
		SaveManager.save_data["money"] = money
		SaveManager.add_purchased("ammo_types", current_ammo_idx)
		PycoLog.log_event_by_type("shop_purchase", {"category": "ammo_types", "id": current_ammo_idx, "price": price})
	SaveManager.save_game()
	update_ui()
func _on_ammo_left_pressed(): current_ammo_idx = (current_ammo_idx - 1 + ammo_types.size()) % ammo_types.size(); update_ui()
func _on_ammo_right_pressed(): current_ammo_idx = (current_ammo_idx + 1) % ammo_types.size(); update_ui()
func _on_equip_to_slot(slot_idx: int):
	var owned = SaveManager.is_purchased("ammo_types", current_ammo_idx) or ammo_types[current_ammo_idx].price == 0
	if not owned:
		return
	# Если снаряд уже в другом слоте — меняем местами
	var existing_slot = ammo_loadout_slots.find(current_ammo_idx)
	if existing_slot != -1 and existing_slot != slot_idx:
		ammo_loadout_slots[existing_slot] = ammo_loadout_slots[slot_idx]
	ammo_loadout_slots[slot_idx] = current_ammo_idx
	SaveManager.set_player_stat("ammo_slot_0", ammo_loadout_slots[0])
	SaveManager.set_player_stat("ammo_slot_1", ammo_loadout_slots[1])
	SaveManager.set_player_stat("ammo_slot_2", ammo_loadout_slots[2])
	SaveManager.save_game()
	update_ui()

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
