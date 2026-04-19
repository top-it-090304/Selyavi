extends Control

@onready var background = $Background
@onready var progress_bar = $CenterContainer/Content/VBox/ProgressBar
@onready var status_label = $CenterContainer/Content/VBox/StatusLabel
@onready var tip_label = $CenterContainer/Content/VBox/TipLabel
@onready var start_button = $CenterContainer/Content/VBox/StartButton

var _target_path: String
var _progress = []
var _use_sub_threads = true
var _is_loaded = false
var _is_boss_level = false

func _ready():
	_target_path = LoadingManager.get_target_path()

	if _target_path == "":
		get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
		return

	# Определяем, уровень ли это с боссом (уровни 5, 10, 15, 20)
	var lvl = SaveManager.current_level if SaveManager else 1
	_is_boss_level = (lvl % 5 == 0)

	ResourceLoader.load_threaded_request(_target_path, "", _use_sub_threads)

	if start_button:
		start_button.visible = false
		start_button.pressed.connect(_on_start_pressed)

	_setup_ui()

func _setup_ui():
	var normal_tips = [
		"Используй штаб для ремонта и усиления урона.",
		"Следи за маркерами по краям экрана.",
		"Разные типы снарядов эффективны в разных ситуациях.",
		"Береги жизни штаба — их нельзя восстановить!",
		"Артиллерия стреляет по наводке разведчиков.",
		"Медлительность карается смертью.",
		"Будь щедрым - дари всем свинец!",
		"Танк оснащен системой автодоводки, её можно отключить."
	]

	var boss_tips = [
		"Твоя броня кажется тебе надежной? Это ненадолго.",
		"Многие не вернулись с этого задания.",
		"Ты уверен, что готов? Ещё можно повернуть назад.",
		"Его пушка не знает промаха.",
		"Твои жизни тают быстрее, чем ты успеваешь выстрелить.",
		"Это будет твоя последняя миссия.",
		"Танки не попадают в рай.",
		"Беги, беги, беги!",
		"Тарелку после гречки можно мыть не сразу.",
		"Дай-ка посмотрю, как твой танк выглядит изнутри",
		"У тебя есть 3 жизни, чтобы победить меня, но мне хватит и одной!",
		"Твои последние слова?.."
	]

	if tip_label:
		var current_tips = boss_tips if _is_boss_level else normal_tips
		tip_label.text = "СОВЕТ: " + current_tips[randi() % current_tips.size()]
		tip_label.add_theme_constant_override("line_spacing", 12)

	if _is_boss_level:
		_apply_boss_visuals()

func _apply_boss_visuals():
	# 1. Плавная смена фона на темно-красный
	if background:
		var style = background.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
		background.add_theme_stylebox_override("panel", style)
		var tween = create_tween()
		tween.tween_property(style, "bg_color", Color(0.18, 0.04, 0.04), 1.5)

	# 2. Окраска Прогресс-бара в красный
	if progress_bar:
		var fill_style = progress_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
		fill_style.bg_color = Color(0.7, 0.1, 0.1)
		fill_style.border_color = Color(1.0, 0.3, 0.3)
		progress_bar.add_theme_stylebox_override("fill", fill_style)

	# 3. Окраска Кнопки в красный
	if start_button:
		var btn_normal = start_button.get_theme_stylebox("normal").duplicate() as StyleBoxFlat
		btn_normal.bg_color = Color(0.35, 0.08, 0.08)
		btn_normal.border_color = Color(0.5, 0.1, 0.1)

		var btn_hover = start_button.get_theme_stylebox("hover").duplicate() as StyleBoxFlat
		btn_hover.bg_color = Color(0.5, 0.1, 0.1)
		btn_hover.border_color = Color(0.7, 0.2, 0.2)

		var btn_pressed = start_button.get_theme_stylebox("pressed").duplicate() as StyleBoxFlat
		btn_pressed.bg_color = Color(0.2, 0.05, 0.05)
		btn_pressed.border_color = Color(0.1, 0.0, 0.0)

		start_button.add_theme_stylebox_override("normal", btn_normal)
		start_button.add_theme_stylebox_override("hover", btn_hover)
		start_button.add_theme_stylebox_override("pressed", btn_pressed)

func _process(_delta):
	if _is_loaded: return

	var status = ResourceLoader.load_threaded_get_status(_target_path, _progress)

	if progress_bar and _progress.size() > 0:
		progress_bar.value = _progress[0] * 100

	match status:
		1: # IN_PROGRESS
			if status_label and _progress.size() > 0:
				status_label.text = "ПОДГОТОВКА... " + str(int(_progress[0] * 100)) + "%"

		3: # LOADED
			_is_loaded = true
			if progress_bar: progress_bar.value = 100

			if _is_boss_level:
				var lvl = SaveManager.current_level if SaveManager else 5
				var boss_name = "ПРИЗЫВАТЕЛЬ" if lvl == 5 else "РИКОШЕТИР"
				status_label.text = boss_name + " ЖДЕТ ТЕБЯ..."
				status_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
			else:
				status_label.text = "ГОТОВО К БОЮ!"

			_show_start_button()

		2: # FAILED
			status_label.text = "ОШИБКА ЗАГРУЗКИ"

		0: # INVALID
			status_label.text = "РЕСУРС НЕ НАЙДЕН"

func _show_start_button():
	if start_button:
		start_button.visible = true
		start_button.modulate.a = 0
		var tween = create_tween()
		tween.tween_property(start_button, "modulate:a", 1.0, 0.5)

func _on_start_pressed():
	var new_scene = ResourceLoader.load_threaded_get(_target_path)
	if new_scene:
		get_tree().change_scene_to_packed(new_scene)
