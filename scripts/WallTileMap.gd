extends TileMapLayer

@export var destructible_wall_scene: PackedScene = preload("res://scenes/Walls/DestructibleWall.tscn")
@export var indestructible_wall_scene: PackedScene = preload("res://scenes/Walls/IndestructibleWall.tscn")

func _ready():
	# Ждем завершения кадра
	await get_tree().process_frame

	var cells = get_used_cells()
	for cell in cells:
		var source_id = get_cell_source_id(cell)
		var wall_instance: Node2D = null

		if source_id == 1:
			wall_instance = destructible_wall_scene.instantiate()
		elif source_id == 2:
			wall_instance = indestructible_wall_scene.instantiate()
		elif source_id == 3:
			# Логика для сезонных стен (Source ID 3)
			var scene_id = get_cell_alternative_tile(cell)
			var source = tile_set.get_source(3) as TileSetScenesCollectionSource
			if source:
				var packed_scene = source.get_scene_tile_scene(scene_id)
				if packed_scene:
					wall_instance = packed_scene.instantiate()

		if wall_instance:
			# Ставим объект в центр клетки
			wall_instance.global_position = map_to_local(cell) + global_position
			get_parent().add_child(wall_instance)

			# Сбрасываем внутренние смещения, чтобы всё стояло четко по центру
			for child in wall_instance.get_children():
				if child is Node2D:
					child.position = Vector2.ZERO

	# Скрываем слой, так как мы заменили все тайлы на живые сцены
	self.visible = false
	self.enabled = false
