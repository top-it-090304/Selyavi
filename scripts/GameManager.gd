extends Node

signal on_visual_scope_updated(is_active)

func _ready():
	if SaveManager != null:
		if not SaveManager.settings_changed.is_connected(_on_settings_update):
			SaveManager.settings_changed.connect(_on_settings_update)

func is_scope_currently_enabled() -> bool:
	if SaveManager == null:
		return true

	var raw_val = SaveManager.get_setting("game", "scope_enabled", true)

	if typeof(raw_val) == TYPE_SIGNAL:
		return true

	return bool(raw_val)

func set_scope_active(new_state: bool):
	if SaveManager != null:
		SaveManager.set_setting("game", "scope_enabled", new_state)
		on_visual_scope_updated.emit(new_state)

func _on_settings_update():
	on_visual_scope_updated.emit(is_scope_currently_enabled())
