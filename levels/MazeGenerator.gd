extends Node2D
class_name MazeGenerator

@onready var tilemap_layer: TileMapLayer = $TileMapLayer
@onready var generate_button: Button = $UI/VBoxContainer/GenerateButton
@onready var clear_button: Button = $UI/VBoxContainer/ClearButton
@onready var width_spinbox: SpinBox = $UI/VBoxContainer/SizeContainer/WidthSpinBox
@onready var height_spinbox: SpinBox = $UI/VBoxContainer/SizeContainer/HeightSpinBox
@onready var info_label: Label = $UI/VBoxContainer/InfoLabel

# Tile source IDs from your tileset
const ARROW_SOURCE_ID = 0  # arrows.png
const TRACK_SOURCE_ID = 1  # cropped.png (railway tracks)
const TRACK_TERRAIN_SET = 0
const TRACK_TERRAIN = 0

# Maze generation variables
var maze: Array[Array]  # 2D array: true = passage (track), false = wall (empty)
var maze_width: int
var maze_height: int

func _ready():
	generate_button.pressed.connect(_on_generate_pressed)
	clear_button.pressed.connect(_on_clear_pressed)
	
	info_label.text = "Status: Ready - Click Generate to create a maze"

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
	"""Convert abstract maze to tilemap"""
	# Clear existing tiles
	tilemap_layer.clear()
	
	# Place track tiles individually with proper terrain connections
	for y in range(maze_height):
		for x in range(maze_width):
			if maze[y][x]:  # If this is a passage
				var pos = Vector2i(x, y)
				place_track_with_connections(pos)
	
	# Force terrain update
	tilemap_layer.notify_runtime_tile_data_update()
	
	# Add start/end arrows
	add_start_end_arrows()

func place_track_with_connections(pos: Vector2i):
	"""Place a track tile with only the connections that should exist"""
	# First place the tile
	tilemap_layer.set_cell(pos, TRACK_SOURCE_ID, Vector2i(0, 0), 0)
	
	# Find which neighbors should connect (only if they're also passages in the maze)
	var connected_neighbors: Array[Vector2i] = []
	var directions = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]  # N, E, S, W
	
	for direction in directions:
		var neighbor_pos = pos + direction
		# Check if neighbor is within bounds and is a passage
		if (neighbor_pos.x >= 0 and neighbor_pos.x < maze_width and
			neighbor_pos.y >= 0 and neighbor_pos.y < maze_height and
			maze[neighbor_pos.y][neighbor_pos.x]):
			connected_neighbors.append(neighbor_pos)
	
	# Apply terrain connect only to this tile and its valid maze neighbors
	var cells_to_connect = [pos] + connected_neighbors
	tilemap_layer.set_cells_terrain_connect(cells_to_connect, TRACK_TERRAIN_SET, TRACK_TERRAIN, false)

func add_start_end_arrows():
	"""Add start and end arrow markers"""
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
	
	# Place arrow tiles with proper directions
	if start_pos != Vector2i.ZERO:
		# Start arrow pointing into the maze (down or right)
		var start_atlas_coords = Vector2i(0, 1)  # Adjust based on your arrow tileset
		tilemap_layer.set_cell(start_pos, ARROW_SOURCE_ID, start_atlas_coords, 0)
	
	if end_pos != Vector2i.ZERO and end_pos != start_pos:
		# End arrow pointing out of the maze (down or right) 
		var end_atlas_coords = Vector2i(1, 1)  # Adjust based on your arrow tileset
		tilemap_layer.set_cell(end_pos, ARROW_SOURCE_ID, end_atlas_coords, 0)