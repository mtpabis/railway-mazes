extends Node2D
class_name MazeGenerator

@onready var passage_tilemap_layer: TileMapLayer = $PassageTileMapLayer
@onready var wall_tilemap_layer: TileMapLayer = $WallTileMapLayer
@onready var object_tilemap_layer: TileMapLayer = $ObjectTileMapLayer
@onready var generate_button: Button = $UI/VBoxContainer/GenerateButton
@onready var clear_button: Button = $UI/VBoxContainer/ClearButton
@onready var width_spinbox: SpinBox = $UI/VBoxContainer/SizeContainer/WidthSpinBox
@onready var height_spinbox: SpinBox = $UI/VBoxContainer/SizeContainer/HeightSpinBox
@onready var style_dropdown: OptionButton = $UI/VBoxContainer/StyleContainer/StyleDropdown
@onready var info_label: Label = $UI/VBoxContainer/InfoLabel
@onready var export_png_button: Button = $UI/VBoxContainer/ExportContainer/ExportPNGButton
@onready var camera: Camera2D = $Camera2D
@onready var fit_maze_button: Button = $UI/VBoxContainer/CameraContainer/CameraButtons/FitMazeButton
@onready var reset_camera_button: Button = $UI/VBoxContainer/CameraContainer/CameraButtons/ResetCameraButton
@onready var zoom_in_button: Button = $UI/VBoxContainer/CameraContainer/ZoomContainer/ZoomInButton
@onready var zoom_out_button: Button = $UI/VBoxContainer/CameraContainer/ZoomContainer/ZoomOutButton
@onready var zoom_label: Label = $UI/VBoxContainer/CameraContainer/ZoomContainer/ZoomLabel

# Available maze styles
@export var available_styles: Array[MazeStyle] = []
var current_style: MazeStyle

# Maze generation variables
var maze: Array[Array]  # 2D array: true = passage (track), false = wall (empty)
var maze_width: int
var maze_height: int

# Export manager
var export_manager: ExportManager

# Camera settings
var default_zoom := Vector2(1.0, 1.0)
var zoom_step := 0.2
var min_zoom := 0.1
var max_zoom := 5.0

func _ready():
	generate_button.pressed.connect(_on_generate_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	style_dropdown.item_selected.connect(_on_style_changed)
	export_png_button.pressed.connect(_on_export_png_pressed)
	fit_maze_button.pressed.connect(_on_fit_maze_pressed)
	reset_camera_button.pressed.connect(_on_reset_camera_pressed)
	zoom_in_button.pressed.connect(_on_zoom_in_pressed)
	zoom_out_button.pressed.connect(_on_zoom_out_pressed)
	
	setup_export_manager()
	setup_styles()
	info_label.text = "Status: Ready - Select style and click Generate"

func setup_styles():
	"""Initialize available styles and populate dropdown"""
	# Populate dropdown with configured styles
	style_dropdown.clear()
	for i in range(available_styles.size()):
		var style = available_styles[i]
		style_dropdown.add_item(style.get_style_display_name())
	
	# Set first style as current
	if not available_styles.is_empty():
		current_style = available_styles[0]
		style_dropdown.selected = 0
		update_tileset()


func _on_style_changed(index: int):
	"""Handle style dropdown selection"""
	if index >= 0 and index < available_styles.size():
		current_style = available_styles[index]
		update_tileset()
		info_label.text = "Status: '%s' - %s" % [current_style.get_style_display_name(), current_style.get_maze_type()]

func update_tileset():
	"""Update tilemaps with current style's tileset"""
	if current_style and current_style.tileset:
		if passage_tilemap_layer:
			passage_tilemap_layer.tile_set = current_style.tileset
		if wall_tilemap_layer:
			wall_tilemap_layer.tile_set = current_style.tileset
		if object_tilemap_layer:
			object_tilemap_layer.tile_set = current_style.tileset

func _on_generate_pressed():
	maze_width = int(width_spinbox.value)
	maze_height = int(height_spinbox.value)
	
	# Ensure odd dimensions for proper maze generation
	if maze_width % 2 == 0:
		maze_width += 1
	if maze_height % 2 == 0:
		maze_height += 1
	
	info_label.text = "Status: Generating maze %dx%d..." % [maze_width, maze_height]
	
	generate_maze()
	place_tiles()
	
	# Auto-fit camera to show the whole maze
	fit_camera_to_maze()
	
	info_label.text = "Status: Generated %dx%d maze successfully!" % [maze_width, maze_height]

func _on_clear_pressed():
	if passage_tilemap_layer:
		passage_tilemap_layer.clear()
	if wall_tilemap_layer:
		wall_tilemap_layer.clear()
	if object_tilemap_layer:
		object_tilemap_layer.clear()
	info_label.text = "Status: Cleared - Ready for new generation"

func generate_maze():
	"""Generate maze using recursive backtracking algorithm"""
	# Initialize maze grid - all walls (false)
	maze = []
	for y in range(maze_height):
		var row: Array[bool] = []
		for x in range(maze_width):
			row.append(false)
		maze.append(row)
	
	# Start from position (1,1) and carve passages
	var stack: Array[Vector2i] = []
	var current = Vector2i(1, 1)
	maze[current.y][current.x] = true  # Mark as passage
	
	while true:
		var neighbors = get_unvisited_neighbors(current)
		
		if neighbors.size() > 0:
			# Choose random neighbor
			var next = neighbors[randi() % neighbors.size()]
			stack.push_back(current)
			
			# Remove wall between current and next
			var wall_x = current.x + (next.x - current.x) / 2
			var wall_y = current.y + (next.y - current.y) / 2
			maze[wall_y][wall_x] = true
			maze[next.y][next.x] = true
			
			current = next
		elif stack.size() > 0:
			current = stack.pop_back()
		else:
			break

func get_unvisited_neighbors(pos: Vector2i) -> Array[Vector2i]:
	"""Get unvisited neighbors that are 2 steps away (for maze generation)"""
	var neighbors: Array[Vector2i] = []
	var directions = [Vector2i(0, -2), Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0)]
	
	for direction in directions:
		var neighbor = pos + direction
		if (neighbor.x > 0 and neighbor.x < maze_width - 1 and 
			neighbor.y > 0 and neighbor.y < maze_height - 1 and
			not maze[neighbor.y][neighbor.x]):
			neighbors.append(neighbor)
	
	return neighbors

func place_tiles():
	"""Convert abstract maze to dual tilemaps using current style"""
	if not current_style:
		info_label.text = "Status: Error - No style selected"
		return
	
	if not current_style.is_valid():
		info_label.text = "Status: Error - Style has no visible elements"
		return
		
	# Clear existing tiles
	if passage_tilemap_layer:
		passage_tilemap_layer.clear()
	if wall_tilemap_layer:
		wall_tilemap_layer.clear()
	if object_tilemap_layer:
		object_tilemap_layer.clear()
	
	# Place passages (if style has passages)
	if current_style.has_passages:
		place_passages()
	
	# Place walls (if style has walls)
	if current_style.has_walls:
		place_walls()
	
	# Place objects (start/end markers, etc.)
	if current_style.has_start_end_objects:
		place_objects()
	
	# Force terrain updates
	if passage_tilemap_layer:
		passage_tilemap_layer.notify_runtime_tile_data_update()
	if wall_tilemap_layer:
		wall_tilemap_layer.notify_runtime_tile_data_update()
	if object_tilemap_layer:
		object_tilemap_layer.notify_runtime_tile_data_update()

func place_walls():
	"""Place wall tiles using terrain system for all non-passage positions"""
	var wall_positions: Array[Vector2i] = []
	
	# Collect all wall positions
	for y in range(maze_height):
		for x in range(maze_width):
			if not maze[y][x]:  # If this is a wall
				var pos = Vector2i(x, y)
				wall_positions.append(pos)
	
	# Apply wall terrain to all wall positions at once
	if wall_positions.size() > 0 and wall_tilemap_layer:
		wall_tilemap_layer.set_cells_terrain_connect(
			wall_positions,
			current_style.wall_terrain_set,
			current_style.wall_terrain_id
		)

func place_passages():
	"""Place passage tiles (tracks/paths) with terrain connections"""
	var passage_positions: Array[Vector2i] = []
	
	# Collect all passage positions
	for y in range(maze_height):
		for x in range(maze_width):
			if maze[y][x]:  # If this is a passage
				var pos = Vector2i(x, y)
				passage_positions.append(pos)
	
	# Apply passage terrain to all passage positions at once
	if passage_positions.size() > 0 and passage_tilemap_layer:
		passage_tilemap_layer.set_cells_terrain_connect(
			passage_positions, 
			current_style.passage_terrain_set, 
			current_style.passage_terrain_id
		)

func place_objects():
	"""Place object tiles (start/end markers) using current style"""
	if not current_style:
		return
		
	# Find start position (top-left area)
	var start_pos = Vector2i.ZERO
	for y in range(maze_height):
		for x in range(maze_width):
			if maze[y][x]:  # Found first passage
				start_pos = Vector2i(x, y)
				break
		if start_pos != Vector2i.ZERO:
			break
	
	# Find end position (bottom-right area)  
	var end_pos = Vector2i.ZERO
	for y in range(maze_height - 1, -1, -1):
		for x in range(maze_width - 1, -1, -1):
			if maze[y][x]:  # Found last passage
				end_pos = Vector2i(x, y)
				break
		if end_pos != Vector2i.ZERO:
			break
	
	# Place start and end object tiles on the object layer (always on top)
	if start_pos != Vector2i.ZERO and object_tilemap_layer:
		object_tilemap_layer.set_cell(
			start_pos, 
			current_style.object_source_id, 
			current_style.start_tile_atlas_coords, 
			current_style.start_tile_alternative
		)
	
	if end_pos != Vector2i.ZERO and end_pos != start_pos and object_tilemap_layer:
		object_tilemap_layer.set_cell(
			end_pos, 
			current_style.object_source_id, 
			current_style.end_tile_atlas_coords, 
			current_style.end_tile_alternative
		)

func setup_export_manager():
	"""Initialize the export manager"""
	export_manager = ExportManager.new(self)
	add_child(export_manager)
	
	# Connect export signals
	export_manager.export_started.connect(_on_export_started)
	export_manager.export_completed.connect(_on_export_completed)
	export_manager.export_failed.connect(_on_export_failed)

func _on_export_png_pressed():
	"""Handle PNG export button press"""
	if not maze or maze.is_empty():
		info_label.text = "Status: Error - Generate a maze first before exporting"
		return
	
	info_label.text = "Status: Exporting PNG..."
	await export_manager.export_maze_png()


func _on_export_started(format: String):
	"""Handle export started signal"""
	info_label.text = "Status: Exporting %s..." % format

func _on_export_completed(format: String, file_path: String):
	"""Handle export completed signal"""
	info_label.text = "Status: %s exported successfully to %s" % [format, file_path.get_file()]

func _on_export_failed(format: String, error: String):
	"""Handle export failed signal"""
	info_label.text = "Status: Export failed - %s" % error

# Camera control functions
func fit_camera_to_maze():
	"""Automatically fit camera to show the entire maze"""
	if not camera or not maze or maze.is_empty():
		return
	
	var maze_bounds = get_display_maze_bounds()
	if maze_bounds.size == Vector2.ZERO:
		return
	
	# Get viewport size
	var viewport_size = get_viewport().get_visible_rect().size
	
	# Calculate the zoom needed to fit the maze in the viewport
	# Leave some padding (20% of viewport on each side)
	var padding_factor = 0.6  # Use 60% of viewport space for maze
	var available_size = viewport_size * padding_factor
	
	var scale_x = available_size.x / maze_bounds.size.x
	var scale_y = available_size.y / maze_bounds.size.y
	var optimal_scale = min(scale_x, scale_y)
	
	# Set camera position to center of maze
	camera.position = maze_bounds.get_center()
	
	# Set camera zoom
	camera.zoom = Vector2(optimal_scale, optimal_scale)
	
	update_zoom_label()

func get_display_maze_bounds() -> Rect2:
	"""Get the bounds of the maze for display purposes (similar to export but for main view)"""
	var min_pos = Vector2(INF, INF)
	var max_pos = Vector2(-INF, -INF)
	var found_tiles = false
	
	# Check all tilemap layers for used cells
	var layers = [passage_tilemap_layer, wall_tilemap_layer, object_tilemap_layer]
	
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
	
	# Add tile size to max_pos
	var tile_size = Vector2(64, 64)  # Default fallback
	if passage_tilemap_layer and passage_tilemap_layer.tile_set:
		var tileset = passage_tilemap_layer.tile_set
		if tileset.get_source_count() > 0:
			var source = tileset.get_source(0)
			if source is TileSetAtlasSource:
				var atlas_source = source as TileSetAtlasSource
				tile_size = Vector2(atlas_source.texture_region_size)
	
	max_pos += tile_size
	
	return Rect2(min_pos, max_pos - min_pos)

func _on_fit_maze_pressed():
	"""Handle fit maze button press"""
	fit_camera_to_maze()

func _on_reset_camera_pressed():
	"""Reset camera to default position and zoom"""
	if camera:
		camera.position = Vector2.ZERO
		camera.zoom = default_zoom
		update_zoom_label()

func _on_zoom_in_pressed():
	"""Zoom in"""
	if camera:
		var new_zoom = camera.zoom + Vector2(zoom_step, zoom_step)
		camera.zoom = Vector2(
			min(new_zoom.x, max_zoom),
			min(new_zoom.y, max_zoom)
		)
		update_zoom_label()

func _on_zoom_out_pressed():
	"""Zoom out"""
	if camera:
		var new_zoom = camera.zoom - Vector2(zoom_step, zoom_step)
		camera.zoom = Vector2(
			max(new_zoom.x, min_zoom),
			max(new_zoom.y, min_zoom)
		)
		update_zoom_label()

func update_zoom_label():
	"""Update the zoom percentage label"""
	if camera and zoom_label:
		var zoom_percent = int(camera.zoom.x * 100)
		zoom_label.text = "%d%%" % zoom_percent
