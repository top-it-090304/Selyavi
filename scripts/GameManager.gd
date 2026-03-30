extends Node

signal scope_toggled(enabled)

var _scope_enabled: bool = true

func get_scope_enabled() -> bool:
	return _scope_enabled

func set_scope_enabled(value: bool):
	_scope_enabled = value
	emit_signal("scope_toggled", _scope_enabled)
	_save_scope_state()

func _ready():
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
