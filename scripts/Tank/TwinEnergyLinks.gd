extends Node2D

var connections: Array = []
var frames: Array[Texture2D] = []
var damage: int = 20
var hit_interval: float = 1.0
var hit_radius: float = 40.0
var animation_fps: float = 24.0
var bend_amplitude: float = 16.0
var segment_length: float = 80.0

var _lines: Array[Line2D] = []
var _time: float = 0.0
var _hit_cooldown: float = 0.0

func _ready():
	for connection in connections:
		var line = Line2D.new()
		line.top_level = true
		line.width = hit_radius * 2.0
		line.default_color = Color.WHITE
		line.texture_mode = Line2D.LINE_TEXTURE_TILE
		line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		line.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		line.z_index = -1
		line.z_as_relative = false
		add_child(line)
		line.global_transform = Transform2D.IDENTITY
		_lines.append(line)
	for connection in connections:
		for endpoint in connection:
			if is_instance_valid(endpoint) and not endpoint.tree_exiting.is_connected(_expire):
				endpoint.tree_exiting.connect(_expire)
	if _endpoints_alive(): _update_lines()

func _expire():
	for line in _lines: line.visible = false
	queue_free()

func _endpoints_alive() -> bool:
	for connection in connections:
		for endpoint in connection:
			if not is_instance_valid(endpoint) or endpoint.is_queued_for_deletion(): return false
			if endpoint is Tank and endpoint._hp <= 0: return false
	return not connections.is_empty()

func _physics_process(delta: float):
	if not _endpoints_alive():
		# Скрываем сразу: queue_free удалит узел только в конце кадра.
		_expire()
		return
	_time += delta
	_update_lines()
	_hit_cooldown = maxf(0.0, _hit_cooldown - delta)
	if _hit_cooldown > 0.0: return
	for player in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(player) or player.is_queued_for_deletion(): continue
		for connection in connections:
			var closest = Geometry2D.get_closest_point_to_segment(player.global_position, connection[0].global_position, connection[1].global_position)
			if player.global_position.distance_to(closest) <= hit_radius:
				player.take_damage(damage)
				# Две стороны одного треугольника не удваивают урон в точке пересечения.
				_hit_cooldown = hit_interval
				return

func _update_lines():
	var step = floori(_time * animation_fps)
	for index in range(connections.size()):
		var from: Vector2 = connections[index][0].global_position
		var to: Vector2 = connections[index][1].global_position
		var separation = to - from
		var perpendicular = separation.normalized().orthogonal()
		var count = maxi(1, ceili(separation.length() / segment_length))
		var line = _lines[index]
		line.clear_points()
		for i in range(count + 1):
			var t = float(i) / count
			var point = from.lerp(to, t)
			if i > 0 and i < count:
				var sample = float(step) + i * 17.17
				var bend = sin(sample * 1.73) * 0.7 + sin(sample * 0.93 + i * 2.1) * 0.3
				point += perpendicular * bend * bend_amplitude * sin(PI * t)
			line.add_point(point)
		if not frames.is_empty(): line.texture = frames[step % frames.size()]
