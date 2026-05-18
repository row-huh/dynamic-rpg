extends Node2D

## Spawns a giant background grass layer behind the main tilemap.
## It copies the tileset from the main tilemap's Ground layer and fills a wide area.

@export var tilemap_path: NodePath
@export var fill_radius: int = 150 # How many tiles to fill outwards in all directions

func _ready() -> void:
	call_deferred("_spawn_grass")


func _spawn_grass() -> void:
	var map_node := get_node_or_null(tilemap_path)
	if not map_node:
		push_warning("BackgroundGrassSpawner: tilemap_path not found.")
		return
	
	var ground_layer := _find_tile_map_layer(map_node)
	if not ground_layer:
		push_warning("BackgroundGrassSpawner: ground layer not found.")
		return
	
	# Create a new TileMapLayer for the background grass
	var bg_layer := TileMapLayer.new()
	bg_layer.name = "BackgroundGrass"
	bg_layer.tile_set = ground_layer.tile_set
	
	# We want this background layer to render BEHIND everything else.
	bg_layer.z_index = -10
	bg_layer.global_position = ground_layer.global_position
	
	# Add it as a child of the spawner
	add_child(bg_layer)
	
	# Identify the grass tile in the tileset by scanning the Ground layer
	var used_cells := ground_layer.get_used_cells()
	var grass_source_id := -1
	var grass_atlas_coords := Vector2i.ZERO
	var grass_alternative_tile := 0
	
	var tile_counts := {}
	for cell in used_cells:
		var source_id := ground_layer.get_cell_source_id(cell)
		var atlas_coords := ground_layer.get_cell_atlas_coords(cell)
		var alternative := ground_layer.get_cell_alternative_tile(cell)
		
		# Only consider tiles that are not empty
		if source_id != -1:
			var key := [source_id, atlas_coords.x, atlas_coords.y, alternative]
			tile_counts[key] = tile_counts.get(key, 0) + 1
	
	# Find the most common tile
	var most_common_key = null
	var max_count := -1
	for key in tile_counts:
		if tile_counts[key] > max_count:
			max_count = tile_counts[key]
			most_common_key = key
			
	if most_common_key:
		grass_source_id = most_common_key[0]
		grass_atlas_coords = Vector2i(most_common_key[1], most_common_key[2])
		grass_alternative_tile = most_common_key[3]
		print("BackgroundGrassSpawner: Detected main grass tile: source_id=%d, coords=%s" % [grass_source_id, grass_atlas_coords])
	else:
		# Fallback if no tiles are found
		grass_source_id = 0
		grass_atlas_coords = Vector2i(0, 0)
		grass_alternative_tile = 0
		print("BackgroundGrassSpawner: Fallback to default tile coords (0,0)")

	# Fill a large grid with this grass tile
	for x in range(-fill_radius, fill_radius):
		for y in range(-fill_radius, fill_radius):
			bg_layer.set_cell(Vector2i(x, y), grass_source_id, grass_atlas_coords, grass_alternative_tile)
			
	print("BackgroundGrassSpawner: Successfully spawned grass background filling a %d x %d tile area." % [fill_radius * 2, fill_radius * 2])


func _find_tile_map_layer(node: Node) -> TileMapLayer:
	if node is TileMapLayer:
		return node as TileMapLayer
	for child in node.get_children():
		var result := _find_tile_map_layer(child)
		if result != null:
			return result
	return null
