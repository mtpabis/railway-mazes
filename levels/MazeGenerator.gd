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
@onready var export_png_button: Button = $UI/VBoxContainer/ExportContainer/ExportButtons/ExportPNGButton
@onready var export_pdf_button: Button = $UI/VBoxContainer/ExportContainer/ExportButtons/ExportPDFButton
@onready var print_preview_button: Button = $UI/VBoxContainer/ExportContainer/ExportButtons/PrintPreviewButton

# Available maze styles
@export var available_styles: Array[MazeStyle] = []
var current_style: MazeStyle

# Maze generation variables
var maze: Array[Array]  # 2D array: true = passage (track), false = wall (empty)
var maze_width: int
var maze_height: int

# Export manager
var export_manager: ExportManager

func _ready():
	generate_button.pressed.connect(_on_generate_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	style_dropdown.item_selected.connect(_on_style_changed)
	export_png_button.pressed.connect(_on_export_png_pressed)
	export_pdf_button.pressed.connect(_on_export_pdf_pressed)
	print_preview_button.pressed.connect(_on_print_preview_pressed)
	
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
	export_manager.export_maze_png()

func _on_export_pdf_pressed():
	"""Handle PDF export button press"""
	info_label.text = "Status: PDF export not yet implemented"

func _on_print_preview_pressed():
	"""Handle print preview button press"""
	info_label.text = "Status: Print preview not yet implemented"

func _on_export_started(format: String):
	"""Handle export started signal"""
	info_label.text = "Status: Exporting %s..." % format

func _on_export_completed(format: String, file_path: String):
	"""Handle export completed signal"""
	info_label.text = "Status: %s exported successfully to %s" % [format, file_path.get_file()]

func _on_export_failed(format: String, error: String):
	"""Handle export failed signal"""
	info_label.text = "Status: Export failed - %s" % error
