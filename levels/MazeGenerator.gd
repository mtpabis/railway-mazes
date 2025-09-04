extends Node2D
class_name MazeGenerator

@onready var tilemap_layer: TileMapLayer = $TileMapLayer
@onready var generate_button: Button = $UI/VBoxContainer/GenerateButton
@onready var clear_button: Button = $UI/VBoxContainer/ClearButton
@onready var width_spinbox: SpinBox = $UI/VBoxContainer/SizeContainer/WidthSpinBox
@onready var height_spinbox: SpinBox = $UI/VBoxContainer/SizeContainer/HeightSpinBox
@onready var style_dropdown: OptionButton = $UI/VBoxContainer/StyleContainer/StyleDropdown
@onready var info_label: Label = $UI/VBoxContainer/InfoLabel

# Available maze styles
@export var available_styles: Array[MazeStyle] = []
var current_style: MazeStyle

# Maze generation variables
var maze: Array[Array]  # 2D array: true = passage (track), false = wall (empty)
var maze_width: int
var maze_height: int

func _ready():
	generate_button.pressed.connect(_on_generate_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	style_dropdown.item_selected.connect(_on_style_changed)
	
	setup_styles()
	info_label.text = "Status: Ready - Select style and click Generate"

func setup_styles():
	"""Initialize available styles and populate dropdown"""
	# If no styles are configured, create a default railway style
	if available_styles.is_empty():
		create_default_railway_style()
	
	# Populate dropdown
	style_dropdown.clear()
	for i in range(available_styles.size()):
		var style = available_styles[i]
		style_dropdown.add_item(style.get_style_display_name())
	
	# Set first style as current
	if not available_styles.is_empty():
		current_style = available_styles[0]
		style_dropdown.selected = 0
		update_tileset()

func create_default_railway_style():
	"""Create a default railway style for backward compatibility"""
	var railway_style = MazeStyle.new()
	railway_style.style_name = "Railway (No Walls)"
	railway_style.tileset = preload("res://levels/tileset.tres")
	railway_style.passage_source_id = 1
	railway_style.passage_terrain_set = 0 
	railway_style.passage_terrain_id = 0
	railway_style.has_walls = false
	railway_style.arrow_source_id = 0
	railway_style.description = "Classic railway tracks with empty walls"
	available_styles.append(railway_style)

func _on_style_changed(index: int):
	"""Handle style dropdown selection"""
	if index >= 0 and index < available_styles.size():
		current_style = available_styles[index]
		update_tileset()
		info_label.text = "Status: Style changed to '%s'" % current_style.get_style_display_name()

func update_tileset():
	"""Update tilemap with current style's tileset"""
	if current_style and current_style.tileset:
		tilemap_layer.tile_set = current_style.tileset

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
	tilemap_layer.clear()
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
	"""Convert abstract maze to tilemap using current style"""
	if not current_style:
		info_label.text = "Status: Error - No style selected"
		return
		
	# Clear existing tiles
	tilemap_layer.clear()
	
	# Place walls first (if style has walls)
	if current_style.has_walls:
		place_walls()
	
	# Place passages (tracks/paths)
	place_passages()
	
	# Force terrain update
	tilemap_layer.notify_runtime_tile_data_update()
	
	# Add start/end arrows
	add_start_end_arrows()

func place_walls():
	"""Place wall tiles for all non-passage positions"""
	for y in range(maze_height):
		for x in range(maze_width):
			if not maze[y][x]:  # If this is a wall
				var pos = Vector2i(x, y)
				tilemap_layer.set_cell(
					pos, 
					current_style.wall_source_id, 
					current_style.wall_atlas_coords, 
					current_style.wall_alternative_tile
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
	
	# Apply terrain to all passage positions at once
	if passage_positions.size() > 0:
		tilemap_layer.set_cells_terrain_connect(
			passage_positions, 
			current_style.passage_terrain_set, 
			current_style.passage_terrain_id
		)

func add_start_end_arrows():
	"""Add start and end arrow markers using current style"""
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
	
	# Place arrow tiles using current style
	if start_pos != Vector2i.ZERO:
		tilemap_layer.set_cell(start_pos, current_style.arrow_source_id, current_style.start_arrow_atlas_coords, 0)
	
	if end_pos != Vector2i.ZERO and end_pos != start_pos:
		tilemap_layer.set_cell(end_pos, current_style.arrow_source_id, current_style.end_arrow_atlas_coords, 0)
