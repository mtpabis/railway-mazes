extends Resource
class_name MazeStyle

@export var style_name: String = "Default Style"
@export var tileset: TileSet

# Passage (track/path) configuration
@export_group("Passages")
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

# Arrow/marker configuration
@export_group("Markers")
@export var arrow_source_id: int = 0
@export var start_arrow_atlas_coords: Vector2i = Vector2i(0, 1)
@export var end_arrow_atlas_coords: Vector2i = Vector2i(1, 1)

# Style description for UI
@export_multiline var description: String = ""

func _init():
	resource_name = style_name

func get_style_display_name() -> String:
	return style_name if style_name != "" else "Unnamed Style"