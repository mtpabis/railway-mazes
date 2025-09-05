extends Node
class_name ExportManager

signal export_started(format: String)
signal export_completed(format: String, file_path: String)
signal export_failed(format: String, error: String)

# Export formats
enum ExportFormat {
	PNG
}

# Export quality settings
enum ExportQuality {
	DRAFT = 150,    # 150 DPI - for screen/web
	PRINT = 300     # 300 DPI - for printing
}

# A4 dimensions in pixels at different DPIs
const A4_LANDSCAPE_DRAFT = Vector2i(1754, 1240)  # 150 DPI
const A4_LANDSCAPE_PRINT = Vector2i(3508, 2480)  # 300 DPI

var maze_generator: MazeGenerator
var export_viewport: SubViewport

func _init(generator: MazeGenerator):
	maze_generator = generator

func setup_export_viewport():
	"""Create dedicated viewport for export rendering"""
	if export_viewport:
		export_viewport.queue_free()
	
	export_viewport = SubViewport.new()
	export_viewport.name = "ExportViewport"
	export_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(export_viewport)

func export_maze_png(quality: ExportQuality = ExportQuality.PRINT) -> String:
	"""Export maze as PNG with specified quality"""
	if not maze_generator:
		export_failed.emit("PNG", "No maze generator available")
		return ""
		
	if not maze_generator.maze or maze_generator.maze.is_empty():
		export_failed.emit("PNG", "No maze generated")
		return ""
	
	export_started.emit("PNG")
	
	var file_path = get_export_file_path("png")
	var success = false
	
	# Get canvas size based on quality
	var canvas_size = A4_LANDSCAPE_PRINT if quality == ExportQuality.PRINT else A4_LANDSCAPE_DRAFT
	
	# Create export viewport with A4 dimensions
	setup_export_viewport()
	export_viewport.size = canvas_size
	
	# Clone maze layers for export (without UI)
	var export_maze = create_export_maze_copy()
	export_viewport.add_child(export_maze)
	
	# Calculate and apply scaling to fit A4
	apply_maze_scaling(export_maze, canvas_size)
	
	# Wait for viewport to render
	await get_tree().process_frame
	await get_tree().process_frame
	
	# Capture and save
	var image = export_viewport.get_texture().get_image()
	if image:
		var error = image.save_png(file_path)
		success = (error == OK)
	
	# Cleanup
	if export_viewport:
		export_viewport.queue_free()
		export_viewport = null
	
	if success:
		export_completed.emit("PNG", file_path)
	else:
		export_failed.emit("PNG", "Failed to save image")
	
	return file_path if success else ""

func create_export_maze_copy() -> Node2D:
	"""Create a copy of the maze without UI elements"""
	var export_node = Node2D.new()
	export_node.name = "ExportMaze"
	
	# Clone passage layer
	if maze_generator.passage_tilemap_layer:
		var passage_copy = duplicate_tilemap_layer(maze_generator.passage_tilemap_layer)
		export_node.add_child(passage_copy)
	
	# Clone wall layer  
	if maze_generator.wall_tilemap_layer:
		var wall_copy = duplicate_tilemap_layer(maze_generator.wall_tilemap_layer)
		export_node.add_child(wall_copy)
	
	# Clone object layer
	if maze_generator.object_tilemap_layer:
		var object_copy = duplicate_tilemap_layer(maze_generator.object_tilemap_layer)
		export_node.add_child(object_copy)
	
	return export_node

func duplicate_tilemap_layer(original: TileMapLayer) -> TileMapLayer:
	"""Create a duplicate of a tilemap layer"""
	var duplicate = TileMapLayer.new()
	duplicate.tile_set = original.tile_set
	duplicate.position = original.position
	duplicate.scale = original.scale
	
	# Copy all used cells
	var used_cells = original.get_used_cells()
	for cell_pos in used_cells:
		var source_id = original.get_cell_source_id(cell_pos)
		var atlas_coords = original.get_cell_atlas_coords(cell_pos)
		var alternative_tile = original.get_cell_alternative_tile(cell_pos)
		duplicate.set_cell(cell_pos, source_id, atlas_coords, alternative_tile)
	
	return duplicate

func apply_maze_scaling(export_maze: Node2D, canvas_size: Vector2i):
	"""Calculate and apply optimal scaling to fit maze in A4 canvas"""
	var maze_bounds = get_maze_bounds()
	if maze_bounds.size == Vector2.ZERO:
		return
	
	# Define margins (10% of canvas size)
	var margin = Vector2(canvas_size.x * 0.1, canvas_size.y * 0.1)
	var available_space = Vector2(canvas_size) - margin * 2
	
	# Calculate optimal scale to fit in available space
	var scale_x = available_space.x / maze_bounds.size.x
	var scale_y = available_space.y / maze_bounds.size.y
	var optimal_scale = min(scale_x, scale_y)
	
	# Apply scaling
	export_maze.scale = Vector2(optimal_scale, optimal_scale)
	
	# Center the maze in canvas
	var scaled_maze_size = maze_bounds.size * optimal_scale
	var center_offset = (Vector2(canvas_size) - scaled_maze_size) / 2
	export_maze.position = center_offset - maze_bounds.position * optimal_scale

func get_maze_bounds() -> Rect2:
	"""Calculate the bounding rectangle of the generated maze"""
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	var found_tiles = false
	
	# Check all tilemap layers for used cells
	var layers = [
		maze_generator.passage_tilemap_layer,
		maze_generator.wall_tilemap_layer,
		maze_generator.object_tilemap_layer
	]
	
	for layer in layers:
		if not layer:
			continue
			
		var used_cells = layer.get_used_cells()
		for cell_pos in used_cells:
			var world_pos = layer.to_global(layer.map_to_local(cell_pos))
			min_pos.x = min(min_pos.x, world_pos.x)
			min_pos.y = min(min_pos.y, world_pos.y)
			max_pos.x = max(max_pos.x, world_pos.x)
			max_pos.y = max(max_pos.y, world_pos.y)
			found_tiles = true
	
	if not found_tiles:
		return Rect2()
	
	# Add tile size to max_pos since we want the full tile coverage
	# Get actual tile size from tileset if available
	var tile_size = Vector2(64, 64)  # Default fallback
	if layers[0] and layers[0].tile_set:
		var tileset = layers[0].tile_set
		if tileset.get_source_count() > 0:
			var source = tileset.get_source(0)
			if source is TileSetAtlasSource:
				var atlas_source = source as TileSetAtlasSource
				tile_size = Vector2(atlas_source.texture_region_size)
	
	max_pos += tile_size
	
	return Rect2(min_pos, max_pos - min_pos)

func get_export_file_path(extension: String) -> String:
	"""Generate timestamped file path for export"""
	var datetime = Time.get_datetime_dict_from_system()
	var timestamp = "%04d%02d%02d_%02d%02d%02d" % [
		datetime.year, datetime.month, datetime.day,
		datetime.hour, datetime.minute, datetime.second
	]
	
	return "user://maze_export_%s.%s" % [timestamp, extension]
