extends Control

@onready var list_container = $UI/CenterContainer/AchievementScroll/AchievementList

const RANK_ORDER := ["bronze", "silver", "gold", "platinum"]

func _ready():
	if has_node("/root/AudioManager"):
		get_node("/root/AudioManager").play_menu()
	_build_list()

func _build_list():
	for child in list_container.get_children():
		child.queue_free()

	var by_rank := {}
	for ach in AchievementManager.ACHIEVEMENTS:
		if not by_rank.has(ach.rank): by_rank[ach.rank] = []
		by_rank[ach.rank].append(ach)

	for rank in RANK_ORDER:
		if not by_rank.has(rank): continue
		for ach in by_rank[rank]:
			list_container.add_child(_build_card(ach))

func _build_card(ach: Dictionary) -> Control:
	var unlocked = AchievementManager.is_unlocked(ach.id)
	var rank_color: Color = AchievementManager.RANK_COLORS.get(ach.rank, Color.WHITE)
	var font = load("res://assets/fonts/ofont.ru_Shonen.ttf")

	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.16, 0.19, 0.16, 1.0) if unlocked else Color(0.12, 0.13, 0.12, 0.85)
	style.set_border_width_all(2); style.border_width_left = 8
	style.border_color = rank_color if unlocked else rank_color.darkened(0.5)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var hbox = HBoxContainer.new(); hbox.add_theme_constant_override("separation", 18); panel.add_child(hbox)

	var rank_label = Label.new()
	rank_label.text = AchievementManager.RANK_NAMES.get(ach.rank, "")
	rank_label.custom_minimum_size = Vector2(110, 0)
	rank_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	rank_label.add_theme_font_size_override("font_size", 18)
	rank_label.add_theme_font_override("font", font)
	rank_label.add_theme_color_override("font_color", rank_color if unlocked else rank_color.darkened(0.4))
	hbox.add_child(rank_label)

	var vbox = VBoxContainer.new(); vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL; vbox.add_theme_constant_override("separation", 6); hbox.add_child(vbox)

	var title_row = HBoxContainer.new(); vbox.add_child(title_row)
	var name_label = Label.new()
	name_label.text = ach.name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.add_theme_font_override("font", font)
	name_label.add_theme_color_override("font_color", Color(0.94, 0.96, 0.92) if unlocked else Color(0.55, 0.58, 0.53))
	title_row.add_child(name_label)

	if unlocked:
		var check_label = Label.new()
		check_label.text = "ПОЛУЧЕНО"
		check_label.add_theme_font_size_override("font_size", 16)
		check_label.add_theme_font_override("font", font)
		check_label.add_theme_color_override("font_color", rank_color)
		title_row.add_child(check_label)

	var desc_label = Label.new()
	desc_label.text = ach.desc
	desc_label.add_theme_font_size_override("font_size", 15)
	desc_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.72) if unlocked else Color(0.5, 0.52, 0.48))
	vbox.add_child(desc_label)

	if ach.mode != "meta":
		var progress = AchievementManager.get_progress(ach.id)
		var bar_row = HBoxContainer.new(); bar_row.add_theme_constant_override("separation", 10); vbox.add_child(bar_row)

		var bar = ProgressBar.new()
		bar.min_value = 0; bar.max_value = max(1, progress.target); bar.value = progress.current
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 16)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var bar_bg = StyleBoxFlat.new(); bar_bg.bg_color = Color(0.08, 0.09, 0.08); bar_bg.set_corner_radius_all(6)
		var bar_fill = StyleBoxFlat.new(); bar_fill.bg_color = rank_color; bar_fill.set_corner_radius_all(6)
		bar.add_theme_stylebox_override("background", bar_bg)
		bar.add_theme_stylebox_override("fill", bar_fill)
		bar_row.add_child(bar)

		var count_label = Label.new()
		count_label.text = str(progress.current) + "/" + str(progress.target)
		count_label.custom_minimum_size = Vector2(70, 0)
		count_label.add_theme_font_size_override("font_size", 14)
		count_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.72))
		bar_row.add_child(count_label)
	else:
		var total = AchievementManager.ACHIEVEMENTS.size() - 1
		var done = 0
		for other in AchievementManager.ACHIEVEMENTS:
			if other.id != ach.id and AchievementManager.is_unlocked(other.id): done += 1
		var meta_label = Label.new()
		meta_label.text = "Достижений получено: " + str(done) + "/" + str(total)
		meta_label.add_theme_font_size_override("font_size", 14)
		meta_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.72))
		vbox.add_child(meta_label)

	return panel

func _on_Return_Button_pressed():
	get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
