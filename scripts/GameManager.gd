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

## 0 = узкий обзор (сильный зум), 100 = широкий. Значение сохраняется в настройках как «FOV».
func get_camera_zoom_from_settings() -> float:
	var p = 50.0
	if SaveManager != null:
		p = float(SaveManager.get_setting("game", "camera_fov", 50.0))
	var t = clampf(p / 100.0, 0.0, 1.0)
	return lerpf(1.22, 0.68, t)
