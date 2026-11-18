extends RefCounted

const STEP: float = 64.0
const MAX_VISITED: int = 384
const DIRECTIONS = [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, -1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(1, 1)]

# За пределами навигации ищем короткий физически свободный путь до её границы.
static func find_path(actor: CharacterBody2D, map: RID) -> PackedVector2Array:
	var shape = actor.get_node("CollisionShape2D") as CollisionShape2D
	var origin = actor.global_position
	var closest = NavigationServer2D.map_get_closest_point(map, origin)
	var max_distance = origin.distance_to(closest) + 640.0
	var excluded: Array[RID] = [actor.get_rid()]
	for group in ["players", "enemies"]:
		for body in actor.get_tree().get_nodes_in_group(group):
			if body is PhysicsBody2D and body.get_rid() not in excluded: excluded.append(body.get_rid())
	var open: Array[Vector2i] = [Vector2i.ZERO]
	var costs = {Vector2i.ZERO: 0.0}
	var parents = {}
	var nearest = {Vector2i.ZERO: closest}
	var closed = {}
	while not open.is_empty() and closed.size() < MAX_VISITED:
		var best = 0
		var best_score = INF
		for i in range(open.size()):
			var cell = open[i]
			var score = costs[cell] + (origin + Vector2(cell) * STEP).distance_to(nearest[cell])
			if score < best_score:
				best = i
				best_score = score
		var cell = open[best]
		open.remove_at(best)
		closed[cell] = true
		var position = origin + Vector2(cell) * STEP
		var destination: Vector2 = nearest[cell]
		if _clear_segment(actor, shape, position, destination, excluded):
			var path: Array[Vector2] = [destination, position]
			var cursor = cell
			while parents.has(cursor):
				cursor = parents[cursor]
				path.append(origin + Vector2(cursor) * STEP)
			path.reverse()
			return PackedVector2Array(path)
		for offset in DIRECTIONS:
			var next: Vector2i = cell + offset
			if closed.has(next): continue
			var point = origin + Vector2(next) * STEP
			if point.distance_to(origin) > max_distance: continue
			var cost = costs[cell] + position.distance_to(point)
			if costs.has(next) and costs[next] <= cost: continue
			if not _clear_segment(actor, shape, position, point, excluded): continue
			costs[next] = cost
			parents[next] = cell
			nearest[next] = NavigationServer2D.map_get_closest_point(map, point)
			if next not in open: open.append(next)
	return PackedVector2Array()

static func _clear_segment(actor: CharacterBody2D, shape: CollisionShape2D, from: Vector2, to: Vector2, excluded: Array[RID]) -> bool:
	var direction = to - from
	var turn = direction.angle() + PI / 2 - actor.global_rotation if not direction.is_zero_approx() else 0.0
	var transform = actor.global_transform.rotated_local(turn) * shape.transform
	transform.origin += from - actor.global_position
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = shape.shape
	query.transform = transform
	query.collision_mask = actor.collision_mask
	query.exclude = excluded
	query.margin = 0.15
	var space = actor.get_world_2d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty(): return false
	query.motion = direction
	var fractions = space.cast_motion(query)
	if fractions[0] < 0.99999: return false
	query.motion = Vector2.ZERO
	query.transform.origin += direction
	return space.intersect_shape(query, 1).is_empty()
