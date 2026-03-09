extends Node
class_name GameManager

static var _instance: GameManager
static var instance: GameManager:
	get:
		return _instance

signal scope_toggled(enabled)

var _scope_enabled: bool = true:
	set(value):
		_scope_enabled = value
		scope_toggled.emit(_scope_enabled)
		_save_scope_state()
	get:
		return _scope_enabled

func _ready():
	_instance = self
	_load_settings()

func _load_settings():
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") == OK:
		_scope_enabled = config.get_value("game", "scope_enabled", true)

func _save_scope_state():
	var config = ConfigFile.new()
	config.load("user://settings.cfg")
	config.set_value("game", "scope_enabled", _scope_enabled)
	config.save("user://settings.cfg")
