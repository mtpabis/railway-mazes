extends Resource
class_name MazeStyle

@export var style_name: String = "Default Style"
@export var tileset: TileSet

# Passage (track/path) configuration
@export_group("Passages")
@export var has_passages: bool = true
@export var passage_source_id: int = 1
@export var passage_terrain_set: int = 0
@export var passage_terrain_id: int = 0

# Wall configuration
@export_group("Walls")
@export var has_walls: bool = true
@export var wall_source_id: int = 0
@export var wall_terrain_set: int = 1
@export var wall_terrain_id: int = 0
@export var wall_atlas_coords: Vector2i = Vector2i(0, 0)  # Fallback for non-terrain walls
@export var wall_alternative_tile: int = 0  # Fallback for non-terrain walls

# Object configuration (start/end markers, items, etc.)
@export_group("Objects")
@export var has_start_end_objects: bool = true
@export var object_source_id: int = 0
@export var start_tile_atlas_coords: Vector2i = Vector2i(0, 0)
@export var end_tile_atlas_coords: Vector2i = Vector2i(1, 0)
@export var start_tile_alternative: int = 0
@export var end_tile_alternative: int = 0

# Style description for UI
@export_multiline var description: String = ""

func _init():
	resource_name = style_name

func get_style_display_name() -> String:
	return style_name if style_name != "" else "Unnamed Style"

func get_maze_type() -> String:
	"""Return a description of what defines the maze"""
	if has_passages and has_walls:
		return "Both passages and walls"
	elif has_passages and not has_walls:
		return "Passages define maze (walls empty)"
	elif not has_passages and has_walls:
		return "Walls define maze (passages empty)" 
	else:
		return "Empty maze (neither passages nor walls)"

func is_valid() -> bool:
	"""Check if the style has at least one visible element"""
	return has_passages or has_walls
