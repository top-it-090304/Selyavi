extends Node

signal achievement_unlocked(id: String)

const RANK_COLORS := {
	"bronze": Color("cd7f32"),
	"silver": Color("c0c0c0"),
	"gold": Color("ffd700"),
	"platinum": Color("b9f2ff"),
}

const RANK_NAMES := {
	"bronze": "БРОНЗА",
	"silver": "СЕРЕБРО",
	"gold": "ЗОЛОТО",
	"platinum": "ПЛАТИНА",
}

const ACHIEVEMENTS := [
	{"id": "first_blood", "name": "Первая кровь", "desc": "Уничтожьте первого бота", "rank": "bronze", "event": "enemy_killed", "mode": "sum", "target": 1},
	{"id": "first_mission", "name": "Разведчик", "desc": "Пройдите первую миссию", "rank": "bronze", "event": "levels_unlocked", "mode": "max", "target": 2},
	{"id": "money_1000", "name": "Первые деньги", "desc": "Заработайте 1000 монет", "rank": "bronze", "event": "money_earned", "mode": "sum", "target": 1000},
	{"id": "kill_100", "name": "Истребитель танков", "desc": "Уничтожьте 100 ботов", "rank": "silver", "event": "enemy_killed", "mode": "sum", "target": 100},
	{"id": "bases_20", "name": "Покоритель баз", "desc": "Уничтожьте 20 вражеских баз", "rank": "silver", "event": "base_destroyed", "mode": "sum", "target": 20},
	{"id": "wave_10", "name": "Волна за волной", "desc": "Продержитесь 10 волн в бесконечном режиме", "rank": "silver", "event": "endless_wave", "mode": "max", "target": 10},
	{"id": "all_missions", "name": "Победитель", "desc": "Пройдите все 20 миссий", "rank": "gold", "event": "levels_unlocked", "mode": "max", "target": 21},
	{"id": "wave_25", "name": "Легенда бесконечности", "desc": "Продержитесь 25 волн в бесконечном режиме", "rank": "gold", "event": "endless_wave", "mode": "max", "target": 25},
	{"id": "boss_kills_5", "name": "Убийца боссов", "desc": "Уничтожьте 5 боссов", "rank": "gold", "event": "boss_killed", "mode": "sum", "target": 5},
	{"id": "bops_double_5", "name": "БОПС-снайпер", "desc": "Убейте 2 противников одним выстрелом БОПС 5 раз", "rank": "silver", "event": "bops_double_kill", "mode": "sum", "target": 5},
	{"id": "bops_double_15", "name": "БОПС-мясник", "desc": "Убейте 2 противников одним выстрелом БОПС 15 раз", "rank": "gold", "event": "bops_double_kill", "mode": "sum", "target": 15},
	{"id": "boss_ricochet_medium", "name": "Рикошетир повержен", "desc": "Уничтожьте босса-рикошетира средним корпусом и пушкой", "rank": "silver", "event": "boss_ricochet_medium", "mode": "sum", "target": 1},
	{"id": "boss_inferno_medium", "name": "Инферно потушен", "desc": "Уничтожьте босса Инферно средним корпусом и пушкой", "rank": "gold", "event": "boss_inferno_medium", "mode": "sum", "target": 1},
	{"id": "level19_light_hull", "name": "Лёгкая победа", "desc": "Пройдите миссию 4.4, используя лёгкий корпус", "rank": "silver", "event": "level19_light_hull", "mode": "sum", "target": 1},
	{"id": "shop_complete", "name": "Всё раскуплено", "desc": "Купите все улучшения и боеприпасы в магазине", "rank": "gold", "event": "shop_purchase", "mode": "custom", "target": 33},
	{"id": "tutorial_skip", "name": "Ветеран", "desc": "Пропустите обучение в миссии 1.1", "rank": "bronze", "event": "tutorial_skipped", "mode": "sum", "target": 1},
	{"id": "platinum", "name": "Платина", "desc": "Получите все остальные достижения", "rank": "platinum", "event": "", "mode": "meta", "target": 0},
]

const SHOP_CATEGORY_TOTALS := {
	"bodies": 5, "guns": 5, "colors": 3, "ammo_types": 6,
	"base_hp": 4, "base_heal": 3, "base_bonus": 3, "base_features": 4,
}

const TOAST_FONT_PATH := "res://assets/fonts/ofont.ru_Shonen.ttf"
const TOAST_VISIBLE_TIME := 4.0

var _toast_layer: CanvasLayer
var _toast_queue: Array = []
var _toast_active: bool = false

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS

	if SaveManager:
		if not SaveManager.save_data.has("achievements"):
			SaveManager.save_data["achievements"] = {}
		if not SaveManager.save_data.has("achievements_unlocked"):
			SaveManager.save_data["achievements_unlocked"] = []

	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 200
	_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().root.add_child.call_deferred(_toast_layer)

func _get_definition(id: String):
	for ach in ACHIEVEMENTS:
		if ach.id == id: return ach
	return null

func is_unlocked(id: String) -> bool:
	if not SaveManager: return false
	return id in SaveManager.save_data.get("achievements_unlocked", [])

func _shop_completion_progress() -> Dictionary:
	var total = 0
	var current = 0
	if SaveManager:
		for cat in SHOP_CATEGORY_TOTALS:
			total += SHOP_CATEGORY_TOTALS[cat]
			current += SaveManager.save_data.get("purchased", {}).get(cat, []).size()
	return {"current": current, "target": total}

func get_progress(id: String) -> Dictionary:
	var ach = _get_definition(id)
	if not ach: return {"current": 0, "target": 0, "unlocked": false}

	if ach.mode == "custom" and ach.id == "shop_complete":
		var p = _shop_completion_progress()
		p["unlocked"] = is_unlocked(id)
		return p

	var current = 0
	if SaveManager:
		current = int(SaveManager.save_data.get("achievements", {}).get(id, 0))
	if is_unlocked(id):
		current = ach.target
	return {"current": min(current, ach.target), "target": ach.target, "unlocked": is_unlocked(id)}

func report(event: String, amount: int = 1):
	if not SaveManager or event == "": return
	var progress_dict = SaveManager.save_data.get("achievements", {})
	var changed = false

	for ach in ACHIEVEMENTS:
		if ach.event != event: continue
		if is_unlocked(ach.id): continue

		if ach.mode == "custom":
			if ach.id == "shop_complete":
				var p = _shop_completion_progress()
				if p.current >= p.target: _unlock(ach.id)
			continue

		var current = int(progress_dict.get(ach.id, 0))
		var updated = current
		match ach.mode:
			"sum": updated = current + amount
			"max": updated = max(current, amount)
		if updated != current:
			progress_dict[ach.id] = updated
			changed = true
		if updated >= ach.target:
			_unlock(ach.id)

	if changed:
		SaveManager.save_data["achievements"] = progress_dict
		SaveManager.save_game()

func _unlock(id: String):
	if is_unlocked(id): return
	if not SaveManager: return

	var unlocked_list = SaveManager.save_data.get("achievements_unlocked", [])
	unlocked_list.append(id)
	SaveManager.save_data["achievements_unlocked"] = unlocked_list
	SaveManager.save_game()

	achievement_unlocked.emit(id)
	_queue_toast(id)
	_check_platinum()

func _check_platinum():
	if is_unlocked("platinum"): return
	for ach in ACHIEVEMENTS:
		if ach.id == "platinum": continue
		if not is_unlocked(ach.id): return
	_unlock("platinum")

# region Toast UI

func _queue_toast(id: String):
	_toast_queue.append(id)
	if not _toast_active:
		_process_toast_queue()

func _process_toast_queue():
	if _toast_queue.is_empty():
		_toast_active = false
		return
	_toast_active = true
	var id = _toast_queue.pop_front()
	_show_toast(id)

func _show_toast(id: String):
	var ach = _get_definition(id)
	if not ach or not is_instance_valid(_toast_layer):
		_process_toast_queue()
		return

	var rank_color = RANK_COLORS.get(ach.rank, Color.WHITE)
	var font = load(TOAST_FONT_PATH)

	var margin = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	margin.offset_left = -400.0; margin.offset_top = 20.0; margin.offset_right = -20.0; margin.offset_bottom = 135.0
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.add_child(margin)

	var panel = PanelContainer.new()
	margin.add_child(panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.11, 0.1, 0.96)
	style.set_border_width_all(3)
	style.border_color = rank_color
	style.set_corner_radius_all(14)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new(); hbox.add_theme_constant_override("separation", 12); panel.add_child(hbox)

	var rank_strip = ColorRect.new()
	rank_strip.color = rank_color
	rank_strip.custom_minimum_size = Vector2(6, 0)
	hbox.add_child(rank_strip)

	var vbox = VBoxContainer.new(); vbox.add_theme_constant_override("separation", 2); hbox.add_child(vbox)

	var rank_label = Label.new()
	rank_label.text = "ДОСТИЖЕНИЕ · " + RANK_NAMES.get(ach.rank, "")
	rank_label.add_theme_font_size_override("font_size", 14)
	rank_label.add_theme_color_override("font_color", rank_color)
	rank_label.add_theme_font_override("font", font)
	vbox.add_child(rank_label)

	var name_label = Label.new()
	name_label.text = ach.name
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", Color(0.94, 0.96, 0.92))
	name_label.add_theme_font_override("font", font)
	vbox.add_child(name_label)

	var desc_label = Label.new()
	desc_label.text = ach.desc
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_font_size_override("font_size", 14)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.72))
	vbox.add_child(desc_label)

	margin.modulate.a = 0.0
	var start_offset = margin.offset_right
	margin.offset_left -= 60.0; margin.offset_right -= 60.0

	var tween_in = create_tween()
	tween_in.set_parallel(true)
	tween_in.tween_property(margin, "modulate:a", 1.0, 0.3)
	tween_in.tween_property(margin, "offset_right", start_offset, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.tween_property(margin, "offset_left", start_offset - 380.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween_in.chain().tween_interval(TOAST_VISIBLE_TIME)
	tween_in.chain().tween_property(margin, "modulate:a", 0.0, 0.4)
	tween_in.finished.connect(func():
		margin.queue_free()
		_process_toast_queue()
	)

# endregion
