extends RefCounted

const BODY_RADIUS: float = 30.0
const MIN_SEPARATION: float = 240.0

# Ищем простреливаемую точку у пути выхода из укрытия, а не стреляем сквозь него.
static func find_target(boss: CharacterBody2D, player: Node2D, stations: Array, distance: float) -> PackedVector2Array:
	var origin = boss.global_position
	var target = player.global_position
	var map = boss.get_node("NavigationAgent2D").get_navigation_map()
	var has_map = map.is_valid() and NavigationServer2D.map_get_iteration_id(map) > 0 and NavigationServer2D.map_get_closest_point_owner(map, target).is_valid()
	var nav_target = NavigationServer2D.map_get_closest_point(map, target) if has_map else target
	var angles: Array[float] = []
	var toward = (target - origin).angle()
	for i in range(36): angles.append(toward + TAU * i / 36.0)
	if has_map:
		var route = NavigationServer2D.map_get_path(map, origin, nav_target, true)
		for point in route:
			if point.distance_to(origin) > 100.0:
				angles.append((point - origin).angle())
	var excluded: Array[RID] = [boss.get_rid()]
	for group in ["enemies", "players"]:
		for body in boss.get_tree().get_nodes_in_group(group):
			if body is PhysicsBody2D and body.get_rid() not in excluded:
				excluded.append(body.get_rid())
	var query = PhysicsShapeQueryParameters2D.new()
	var shape = CircleShape2D.new()
	shape.radius = BODY_RADIUS
	query.shape = shape
	query.collision_mask = 1
	query.exclude = excluded
	query.margin = 0.1
	var space = boss.get_world_2d().direct_space_state
	var result = PackedVector2Array()
	var best_score = -INF
	for angle in angles:
		var point = origin + Vector2.RIGHT.rotated(angle) * distance
		var separated = true
		for station in stations:
			if point.distance_to(station.target_position) < MIN_SEPARATION or point.distance_to(station.global_position) < MIN_SEPARATION:
				separated = false
				break
		if not separated: continue
		query.transform = Transform2D(0.0, origin)
		query.motion = Vector2.ZERO
		if not space.intersect_shape(query, 1).is_empty(): continue
		query.motion = point - origin
		if space.cast_motion(query)[0] < 0.99999: continue
		query.motion = Vector2.ZERO
		query.transform.origin = point
		if not space.intersect_shape(query, 1).is_empty(): continue
		var path_length = point.distance_to(target)
		var exit_distance = path_length
		if has_map:
			var nav_point = NavigationServer2D.map_get_closest_point(map, point)
			if nav_point.distance_to(point) > 24.0: continue
			var path = NavigationServer2D.map_get_path(map, nav_target, nav_point, true)
			if path.size() < 2 or path[path.size() - 1].distance_to(nav_point) > 24.0: continue
			path_length = 0.0
			for i in range(1, path.size()): path_length += path[i - 1].distance_to(path[i])
			# Первый поворот пути со стороны игрока — ближайший выход из укрытия.
			exit_distance = point.distance_to(path[1])
		var score = -path_length - exit_distance * 0.75
		if score > best_score:
			best_score = score
			result = PackedVector2Array([point])
	return result
