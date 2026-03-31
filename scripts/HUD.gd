extends CanvasLayer

var _healthProgress: ProgressBar
var _healthLabel: Label
var _livesLabel: Label
var _moneyLabel: Label
var _player

func _ready():
	var healthPanel = get_node_or_null("HealthPanel")
	if healthPanel == null:
		return
	
	_healthProgress = healthPanel.get_node_or_null("HealthProgress")
	_healthLabel = healthPanel.get_node_or_null("HealthLabel")
	_livesLabel = healthPanel.get_node_or_null("LivesLabel")
	_moneyLabel = healthPanel.get_node_or_null("MoneyLabel")
	
	if _healthProgress == null or _healthLabel == null:
		return
	
	_setup_progress_bar_style()
	_healthProgress.min_value = 0
	_healthProgress.max_value = 100
	_healthProgress.value = 100
	_healthProgress.percent_visible = false
	
	call_deferred("_find_player_and_connect")

func _find_player_and_connect():
	_player = get_tree().get_root().find_node("Player", true, false)
	
	if _player == null:
		_player = get_tree().get_root().find_node("PlayerTank", true, false)
	
	if _player != null:
		if _player.has_signal("health_changed") and not _player.is_connected("health_changed", self, "_on_health_changed"):
			_player.connect("health_changed", self, "_on_health_changed")
		
		if _player.has_signal("lives_changed") and not _player.is_connected("lives_changed", self, "_on_lives_changed"):
			_player.connect("lives_changed", self, "_on_lives_changed")
		
		if _player.has_signal("money_changed") and not _player.is_connected("money_changed", self, "_on_money_changed"):
			_player.connect("money_changed", self, "_on_money_changed")
		
		var current_health = 100
		var max_health = 100
		var current_lives = 3
		var current_money = 0
		
		if _player.has_method("get_current_health"):
			current_health = _player.get_current_health()
		if _player.has_method("get_max_health"):
			max_health = _player.get_max_health()
		if _player.has_method("get_lives"):
			current_lives = _player.get_lives()
		if _player.has_method("get_money"):
			current_money = _player.get_money()
		
		var display_health = max(0, current_health)
		
		_healthProgress.max_value = max_health
		_healthProgress.value = display_health
		_healthLabel.text = str(display_health) + "/" + str(max_health)
		
		if _livesLabel != null:
			_livesLabel.text = "Жизни: " + str(current_lives)
		
		if _moneyLabel != null:
			_moneyLabel.text =str(current_money)
		
		_update_health_color(display_health, max_health)
	else:
		get_tree().create_timer(0.5).connect("timeout", self, "_find_player_and_connect")

func _setup_progress_bar_style():
	if _healthProgress == null:
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
	
	_healthProgress.add_stylebox_override("under", background_style)
	_healthProgress.add_stylebox_override("fg", progress_style)

func _on_health_changed(current_health: int, max_health: int):
	if _healthProgress == null or _healthLabel == null:
		return
	
	var display_health = max(0, current_health)
	
	_healthProgress.value = display_health
	_healthLabel.text = str(display_health) + "/" + str(max_health)
	_update_health_color(display_health, max_health)

func _on_lives_changed(current_lives: int):
	if _livesLabel == null:
		return
	_livesLabel.text = "Жизни: " + str(current_lives)

func _on_money_changed(current_money: int):
	if _moneyLabel == null:
		return
	_moneyLabel.text = str(current_money)

func _update_health_color(current_health: int, max_health: int):
	var percent = float(current_health) / float(max_health)
	var style = _healthProgress.get_stylebox("fg")
	if style is StyleBoxFlat:
		var flat_style = style as StyleBoxFlat
		if percent <= 0.3:
			flat_style.bg_color = Color(1, 0.2, 0.2)
		elif percent <= 0.6:
			flat_style.bg_color = Color(1, 0.8, 0.2)
		else:
			flat_style.bg_color = Color(0.2, 0.8, 0.2)
		
		_healthProgress.add_stylebox_override("fg", flat_style)
