extends CanvasLayer

signal tutorial_finished

# Основные узлы планшета
@onready var image_rect = $UI/MainPanel/ContentContainer/ImageRect
@onready var text_label = $UI/MainPanel/ContentContainer/TextLabel
@onready var prev_btn = $UI/MainPanel/PrevButton
@onready var next_btn = $UI/MainPanel/NextButton
@onready var finish_btn = $UI/MainPanel/FinishButton
@onready var skip_btn = $UI/MainPanel/SkipButton

# Узлы для интерактивного FOV
@onready var fov_container = $UI/MainPanel/ContentContainer/FOVSliderContainer
@onready var fov_slider = $UI/MainPanel/ContentContainer/FOVSliderContainer/FOVSlider
@onready var main_panel = $UI/MainPanel
@onready var bg_dimmer = $BackgroundDimmer

var _current_page = 0

# Контент туториала
var _steps = [
	{
		"text": "Тебя давно не было видно, Командир! Мы подготовили для тебя краткий курс перед выходом на задание.",
		"image": ""
	},
	{
		"text": "Обзор — твоё тактическое преимущество. Настрой его ползунком выше, пока не увидишь танка врага полностью.",
		"image": "",
		"is_fov": true
	},
	{
		"text": "Левый джойстик служит для перемещения твоего танка. Маневрируй, чтобы не стать легкой мишенью для врага!",
		"image": "res://Images/tutorialImages/LeftJoystick.png"
	},
	{
		"text": "Правый джойстик отвечает за стрельбу.",
		"image": "res://Images/tutorialImages/RightJoystick.png"
	},
	{
		"text": "Твой танк оснащен автодоводкой. Если можешь справиться без неё, всегда можешь отключить её в настройках",
		"image": ""
	},
	{
		"text": "На поле боя встречаются разные препятствия. Одни стены можно разрушить, другие - нет.",
		"image": "res://Images/tutorialImages/Walls.png"
	},
	{
		"text": "Враги атакуют тебя и штаб. Уничтожь их первым, пока они не нанесли фатальный урон!",
		"image": "res://Images/tutorialImages/EnemyTank.png"
	},
	{
		"text": "Это - твой штаб. Находясь рядом с ним, ты постепенно восстанавливаешь свою броню. Защищай его любой ценой!",
		"image": "res://Images/tutorialImages/PlayersBase.png"
	},
	{
		"text": "А это штаб противника. Твоя главная цель — найти и уничтожить всех их!",
		"image": "res://Images/tutorialImages/EnemyBase.png"
	},
	{
		"text": "Также ты должен уничтожить всех врагов для завершения миссии.",
		"image": ""
	},
	{
		"text": "В нижней части экрана расположена панель выбора снарядов. Каждый подходит к разным условиям боя.",
		"image": "res://Images/tutorialImages/Shells.png"
	},
	{
		"text": "Следи за показателями вверху экрана: твоё здоровье, запас жизней, деньги и счетчик вражеских баз.",
		"image": "res://Images/tutorialImages/HUD.png"
	},
	{
		"text": "На эти деньги ты сможешь улучшить свой танк в магазине.",
		"image": ""
	},
	{
		"text": "Маркеры по краям экрана помогут тебе найти врагов и их штабы вне поля зрения.",
		"image": "res://Images/tutorialImages/MarkerBase.png"
	},
	{
		"text": "Особые маркеры укажут путь к боссам.",
		"image": "res://Images/tutorialImages/MarkersBossEnemy.png"
	},
	{
		"text": "В бой, Командир!",
		"image": ""
	}
]

func _ready():
	add_to_group("tutorial")
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

	# Инициализация ползунка FOV
	if fov_slider:
		fov_slider.focus_mode = Control.FOCUS_NONE
		fov_slider.min_value = 0
		fov_slider.max_value = 100

		# Загружаем текущее значение
		if SaveManager:
			fov_slider.value = SaveManager.get_setting("game", "camera_fov", 80.0)

		# Подключаем сигналы
		fov_slider.drag_started.connect(_on_fov_drag_started)
		fov_slider.drag_ended.connect(_on_fov_drag_ended)
		fov_slider.value_changed.connect(_on_fov_value_changed)

	# Убираем фокус у всех кнопок
	for btn in [prev_btn, next_btn, finish_btn, skip_btn]:
		if btn: btn.focus_mode = Control.FOCUS_NONE

	_update_ui()

func _update_ui():
	var step = _steps[_current_page]

	# Текст
	text_label.text = step.text

	# Картинка (авто-скрытие)
	if step.get("image", "") != "" and FileAccess.file_exists(step.image):
		image_rect.texture = load(step.image)
		image_rect.visible = true
	else:
		image_rect.visible = false

	# Показываем ползунок только на слайде FOV
	if fov_container:
		fov_container.visible = step.get("is_fov", false)

	# Навигация
	prev_btn.visible = (_current_page > 0)
	var is_last = (_current_page == _steps.size() - 1)
	next_btn.visible = !is_last
	finish_btn.visible = is_last

# --- ЛОГИКА ИНТЕРАКТИВНОГО FOV ---

func _on_fov_drag_started():
	# Экран "светлеет": убираем затемнение и делаем планшет прозрачным
	var tween = create_tween().set_parallel(true)
	tween.tween_property(bg_dimmer, "modulate:a", 0.0, 0.25)
	tween.tween_property(main_panel, "modulate:a", 0.3, 0.25)

func _on_fov_drag_ended(_value_changed: bool):
	# Возвращаем планшет в нормальное состояние
	var tween = create_tween().set_parallel(true)
	tween.tween_property(bg_dimmer, "modulate:a", 1.0, 0.25)
	tween.tween_property(main_panel, "modulate:a", 1.0, 0.25)

	# Сохраняем настройки окончательно
	if SaveManager: SaveManager.save_settings()

func _on_fov_value_changed(value: float):
	if SaveManager:
		# Устанавливаем настройку. Это вызовет сигнал settings_changed,
		# который Player.gd поймает и обновит камеру мгновенно.
		SaveManager.set_setting("game", "camera_fov", value)

# --- НАВИГАЦИЯ ---

func _on_next_pressed():
	if _current_page < _steps.size() - 1:
		_current_page += 1
		_update_ui()

func _on_prev_pressed():
	if _current_page > 0:
		_current_page -= 1
		_update_ui()

func _on_skip_pressed():
	_finish_tutorial()

func _finish_tutorial():
	get_tree().paused = false

	# Убираем себя из группы ДО обновления HUD, чтобы HUD увидел, что туториала больше нет
	remove_from_group("tutorial")

	# Принудительно обновляем прозрачность HUD
	var huds = get_tree().get_nodes_in_group("hud")
	for hud in huds:
		if hud.has_method("refresh_hud_opacity"):
			hud.refresh_hud_opacity()

	tutorial_finished.emit()
	queue_free()
