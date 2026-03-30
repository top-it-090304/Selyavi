extends CanvasLayer

var _health_progress: ProgressBar
var _health_label: Label
var _lives_label: Label
var _money_label: Label
var _player: Node

func _ready():
	var health_panel = get_node_or_null("HealthPanel")
	if health_panel == null:
		return
	
	_health_progress = health_panel.get_node_or_null("HealthProgress")
	_health_label = health_panel.get_node_or_null("HealthLabel")
	_lives_label = health_panel.get_node_or_null("LivesLabel")
	_money_label = health_panel.get_node_or_null("MoneyLabel")
	
	if _health_progress == null or _health_label == null:
		return
	
	_setup_progress_bar_style()
	_health_progress.min_value = 0
	_health_progress.max_value = 100
	_health_progress.value = 100
	_health_progress.percent_visible = false
	
	call_deferred("_find_player_and_connect")

func _find_player_and_connect():
	_player = get_tree().root.find_node("Player", true, false)
	
	if _player == null:
		_player = get_tree().root.find_node("PlayerTank", true, false)
	
	if _player != null:
		if not _player.is_connected("health_changed", self, "_on_health_changed"):
			_player.connect("health_changed", self, "_on_health_changed")
		
		if not _player.is_connected("lives_changed", self, "_on_lives_changed"):
			_player.connect("lives_changed", self, "_on_lives_changed")
		
		if not _player.is_connected("money_changed", self, "_on_money_changed"):
			_player.connect("money_changed", self, "_on_money_changed")
		
		var current_health = _player.get_current_health()
		var max_health = _player.get_max_health()
		var current_lives = _player.get_lives()
		var current_money = _player.get_money()
		
		var display_health = max(0, current_health)
		
		_health_progress.max_value = max_health
		_health_progress.value = display_health
		_health_label.text = str(display_health) + "/" + str(max_health)
		
		if _lives_label != null:
			_lives_label.text = "Жизни: " + str(current_lives)
		
		if _money_label != null:
			_money_label.text = "💰 " + str(current_money)
		
		_update_health_color(display_health, max_health)
	else:
		get_tree().create_timer(0.5).connect("timeout", self, "_find_player_and_connect")

func _setup_progress_bar_style():
	if _health_progress == null:
		return
	
	var background_style = StyleBoxFlat.new()
	background_style.bg_color = Color(0.1, 0.1, 0.1)
	background_style.border_width_bottom = 2
	background_style.border_width_top = 2
	background_style.border_width_left = 2
	background_style.border_width_right = 2
	background_style.border_color = Color(0.3, 0.3, 0.3)
	background_style.corner_radius_bottom_left = 5
	background_style.corner_radius_bottom_right = 5
	background_style.corner_radius_top_left = 5
	background_style.corner_radius_top_right = 5

	var progress_style = StyleBoxFlat.new()
	progress_style.bg_color = Color(0.2, 0.8, 0.2)
	progress_style.corner_radius_bottom_left = 5
	progress_style.corner_radius_bottom_right = 5
	progress_style.corner_radius_top_left = 5
	progress_style.corner_radius_top_right = 5
	
	_health_progress.add_stylebox_override("under", background_style)
	_health_progress.add_stylebox_override("fg", progress_style)

func _on_health_changed(current_health: int, max_health: int):
	if _health_progress == null or _health_label == null:
		return
	
	var display_health = max(0, current_health)
	
	_health_progress.value = display_health
	_health_label.text = str(display_health) + "/" + str(max_health)
	_update_health_color(display_health, max_health)

func _on_lives_changed(current_lives: int):
	if _lives_label == null:
		return
	_lives_label.text = "Жизни: " + str(current_lives)

func _on_money_changed(current_money: int):
	if _money_label == null:
		return
	_money_label.text = "💰 " + str(current_money)

func _update_health_color(current_health: int, max_health: int):
	var percent = float(current_health) / max_health
	var style = _health_progress.get_stylebox("fg")
	if style is StyleBoxFlat:
		var flat_style = style as StyleBoxFlat
		if percent <= 0.3:
			flat_style.bg_color = Color(1.0, 0.2, 0.2)
		elif percent <= 0.6:
			flat_style.bg_color = Color(1.0, 0.8, 0.2)
		else:
			flat_style.bg_color = Color(0.2, 0.8, 0.2)
		
		_health_progress.add_stylebox_override("fg", flat_style)
