extends TileMapLayer

@export var destructible_wall_scene: PackedScene = preload("res://scenes/DestructibleWall.tscn")
@export var indestructible_wall_scene: PackedScene = preload("res://scenes/IndestructibleWall.tscn")

func _ready():
	# Ждем завершения кадра, чтобы сцена прогрузилась
	await get_tree().process_frame

	var cells = get_used_cells()
	for cell in cells:
		var source_id = get_cell_source_id(cell)
		var wall_instance: Node2D = null

		# Исправленная логика привязки к Source ID:
		# В TileSet Level_1: Source 1 = Block_A_02, Source 2 = Block_C_02
		# По твоим сценам: Block_A_02 используется в DestructibleWall, Block_C_02 в IndestructibleWall.
		if source_id == 1:
			wall_instance = destructible_wall_scene.instantiate()
		elif source_id == 2:
			wall_instance = indestructible_wall_scene.instantiate()

		if wall_instance:
			# Ставим объект в глобальные координаты центра тайла
			wall_instance.global_position = map_to_local(cell) + global_position
			get_parent().add_child(wall_instance)

			# Принудительно сбрасываем смещение спрайта и коллизии внутри инстанса,
			# чтобы стена стояла ровно по сетке TileMap, игнорируя (54, -53) из сцены.
			for child in wall_instance.get_children():
				if child is Node2D:
					child.position = Vector2.ZERO

	# Отключаем и скрываем оригинальный слой тайлмапа
	self.enabled = false
	self.visible = false
