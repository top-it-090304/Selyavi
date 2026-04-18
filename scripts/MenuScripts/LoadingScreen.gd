extends Control

@onready var progress_bar = $CenterContainer/Content/VBox/ProgressBar
@onready var status_label = $CenterContainer/Content/VBox/StatusLabel
@onready var tip_label = $CenterContainer/Content/VBox/TipLabel
@onready var start_button = $CenterContainer/Content/VBox/StartButton

var _target_path: String
var _progress = []
var _use_sub_threads = true
var _is_loaded = false

func _ready():
	_target_path = LoadingManager.get_target_path()

	if _target_path == "":
		get_tree().change_scene_to_file("res://scenes/MenuScenes/Menu.tscn")
		return

	# Запрашиваем фоновую загрузку
	ResourceLoader.load_threaded_request(_target_path, "", _use_sub_threads)

	if start_button:
		start_button.visible = false
		start_button.pressed.connect(_on_start_pressed)

	_setup_ui()

func _setup_ui():
	var tips = [
		"Используй штаб для ремонта и усиления урона.",
		"Следи за мигающими маркерами по краям экрана.",
		"Разные типы снарядов эффективны в разных ситуациях.",
		"Береги жизни штаба — их нельзя восстановить!",
		"Артиллерия стреляет по наводке разведчиков.",
		"Медлительность карается смертью.",
		"Будь щедрым - дари всем свинец!",
		"Танк оснащен системой автодоводки, её можно отключить в настройках.",
		"Идеального момента никогда не бывает. Действуй здесь и сейчас."
	]
	if tip_label:
		tip_label.text = "СОВЕТ: " + tips[randi() % tips.size()]
		# Увеличиваем межстрочный интервал
		tip_label.add_theme_constant_override("line_spacing", 12)

func _process(_delta):
	if _is_loaded: return

	var status = ResourceLoader.load_threaded_get_status(_target_path, _progress)

	# Обновляем прогресс-бар (значение от 0.0 до 1.0)
	if progress_bar and _progress.size() > 0:
		progress_bar.value = _progress[0] * 100

	match status:
		1: # IN_PROGRESS
			if status_label and _progress.size() > 0:
				status_label.text = "ПОДГОТОВКА... " + str(int(_progress[0] * 100)) + "%"

		3: # LOADED
			_is_loaded = true
			if status_label: status_label.text = "ГОТОВО К БОЮ!"
			if progress_bar: progress_bar.value = 100
			_show_start_button()

		2: # FAILED
			if status_label: status_label.text = "ОШИБКА ЗАГРУЗКИ"
			push_error("Loading failed for: " + _target_path)

		0: # INVALID
			if status_label: status_label.text = "РЕСУРС НЕ НАЙДЕН"

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
