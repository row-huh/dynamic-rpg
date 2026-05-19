extends Node2D

## Spawns StaticBody2D collision on object-layer Sprite2D props using TileSet polygons
## authored in the Fantasy Tileset .tsx files (imported by YATI).

@export var map_root_path: NodePath
@export var skip_name_substrings: Array[String] = ["Shadow"]
@export var fallback_enabled: bool = true
@export var fallback_size_scale: Vector2 = Vector2(0.5, 0.35)

## Maximum pixel size (both width AND height must be <=) to auto-skip
## collision for tiny decorative ground detail sprites.
@export var max_detail_size: int = 16

## Texture filenames (basename only) to always skip collision for,
## regardless of whether they have tileset-authored polygons.
var _skip_texture_filenames: Array[String] = [
	"Plant_2.png",
	"Bush_Emerald_5.png",
	"Bush_Emerald_6.png",
	"Bush_Emerald_7.png",
	"Rock_Brown_6.png",
	"Rock_Brown_9.png",
]

var _spawned_count: int = 0
var _polygon_count: int = 0
var _fallback_count: int = 0


func _ready() -> void:
	call_deferred("_spawn_all")


func _spawn_all() -> void:
	var map_root := _resolve_map_root()
	if map_root == null:
		push_warning("ObjectCollisionSpawner: map_root not found.")
		return

	var tile_set := _find_tile_set(map_root)
	if tile_set == null:
		push_warning("ObjectCollisionSpawner: no TileSet on map.")
		return

	var index := _build_texture_collision_index(tile_set)
	_collect_and_spawn(map_root, index)
	print(
		"ObjectCollisionSpawner: %d bodies (%d tile polygons, %d fallbacks)"
		% [_spawned_count, _polygon_count, _fallback_count]
	)


func _resolve_map_root() -> Node:
	if map_root_path != NodePath():
		return get_node_or_null(map_root_path)
	return null


func _find_tile_set(root: Node) -> TileSet:
	var layer := _find_tile_map_layer(root)
	if layer:
		return layer.tile_set
	return null


func _find_tile_map_layer(node: Node) -> TileMapLayer:
	if node is TileMapLayer:
		return node as TileMapLayer
	for child in node.get_children():
		var found := _find_tile_map_layer(child)
		if found:
			return found
	return null


func _build_texture_collision_index(tile_set: TileSet) -> Dictionary:
	var index: Dictionary = {}
	var physics_layer := 0

	for i in range(tile_set.get_source_count()):
		var source_id := tile_set.get_source_id(i)
		var source := tile_set.get_source(source_id)
		if source is not TileSetAtlasSource:
			continue
		var atlas := source as TileSetAtlasSource
		if atlas.texture == null:
			continue

		var path := atlas.texture.resource_path
		if path.is_empty():
			continue

		var path_entry = {
			"tile_size": atlas.texture_region_size,
			"margins": atlas.margins,
			"separation": atlas.separation,
			"tiles": {}
		}

		for tile_idx in range(atlas.get_tiles_count()):
			var tile_coords := atlas.get_tile_id(tile_idx)
			var td := atlas.get_tile_data(tile_coords, 0)
			if td == null:
				continue

			var polygons: Array = []
			var poly_count := td.get_collision_polygons_count(physics_layer)
			for poly_idx in range(poly_count):
				var pts := td.get_collision_polygon_points(physics_layer, poly_idx)
				if pts.size() < 3:
					continue
				var transformed := PackedVector2Array()
				for p in pts:
					transformed.append(p)
				polygons.append(transformed)

			if not polygons.is_empty():
				path_entry["tiles"][tile_coords] = polygons

		index[path] = path_entry

	return index


func _collect_and_spawn(node: Node, index: Dictionary) -> void:
	for child in node.get_children():
		if child is Sprite2D:
			_maybe_spawn_for_sprite(child as Sprite2D, index)
		if child.get_child_count() > 0:
			_collect_and_spawn(child, index)


func _should_skip(sprite: Sprite2D) -> bool:
	if sprite.get_node_or_null("ObjectCollision") != null:
		return true
	var node_name := str(sprite.name)
	for sub in skip_name_substrings:
		if sub != "" and sub.to_lower() in node_name.to_lower():
			return true
	return false


func _maybe_spawn_for_sprite(sprite: Sprite2D, index: Dictionary) -> void:
	if _should_skip(sprite):
		return
	var tex := sprite.texture
	if tex == null:
		return

	var path := tex.resource_path
	var filename := path.get_file()

	if "Purple" in filename and "Banner" not in filename:
		print("[SPAWNER DEBUG] Purple house sprite: ", sprite.name)
		print("  node_path: ", sprite.get_path())
		print("  parent: ", sprite.get_parent().name if sprite.get_parent() else "null")
		print("  position (local): ", sprite.position)
		print("  global_position: ", sprite.global_position)
		print("  region_enabled: ", sprite.region_enabled)
		print("  offset: ", sprite.offset)
		print("  scale: ", sprite.scale)
		print("  in_index: ", index.has(path))

	# Skip explicitly listed decorative textures
	if filename in _skip_texture_filenames:
		return

	# Skip tiny non-atlas textures (ground detail decorations)
	if not sprite.region_enabled:
		var tex_size := tex.get_size()
		if tex_size.x <= max_detail_size and tex_size.y <= max_detail_size:
			return

	if not index.has(path):
		if fallback_enabled:
			_spawn_fallback(sprite)
		return

	var path_entry: Dictionary = index[path]
	var tile_coords := Vector2i(0, 0)

	if sprite.region_enabled:
		var region_pos := sprite.region_rect.position
		var tile_size: Vector2i = path_entry["tile_size"]
		var margins: Vector2i = path_entry["margins"]
		var separation: Vector2i = path_entry["separation"]

		var grid_x := 0
		var grid_y := 0
		if tile_size.x + separation.x > 0:
			grid_x = int(round((region_pos.x - margins.x) / (tile_size.x + separation.x)))
		if tile_size.y + separation.y > 0:
			grid_y = int(round((region_pos.y - margins.y) / (tile_size.y + separation.y)))
		tile_coords = Vector2i(grid_x, grid_y)

	var tiles: Dictionary = path_entry["tiles"]
	if "Purple" in filename and "Banner" not in filename:
		print("  tile_coords: ", tile_coords, "  tiles has it: ", tiles.has(tile_coords))
		print("  tiles keys: ", tiles.keys())
	if tiles.has(tile_coords):
		var polygons: Array = tiles[tile_coords]
		if "Purple" in filename and "Banner" not in filename:
			print("  -> calling _spawn_polygon_body with ", polygons.size(), " polygons")
		_spawn_polygon_body(sprite, polygons)
		if "Purple" in filename and "Banner" not in filename:
			print("  -> done. child ObjectCollision exists: ", sprite.get_node_or_null('ObjectCollision') != null)


func _spawn_polygon_body(sprite: Sprite2D, polygons: Array) -> void:
	var body := StaticBody2D.new()
	body.name = "ObjectCollision"
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.position = sprite.offset
	sprite.add_child(body)

	for poly in polygons:
		if poly is not PackedVector2Array:
			continue
		var shape := CollisionPolygon2D.new()
		shape.polygon = poly
		body.add_child(shape)
		_polygon_count += 1

	_spawned_count += 1


func _spawn_fallback(sprite: Sprite2D) -> void:
	var tex := sprite.texture
	var size := sprite.region_rect.size * sprite.scale if sprite.region_enabled else tex.get_size() * sprite.scale
	if size.x < 8.0 and size.y < 8.0:
		return

	var body := StaticBody2D.new()
	body.name = "ObjectCollision"
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
	body.position = sprite.offset
	sprite.add_child(body)

	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(
		maxf(size.x * fallback_size_scale.x, 8.0),
		maxf(size.y * fallback_size_scale.y, 8.0)
	)
	shape.shape = rect
	shape.position = Vector2(0, rect.size.y * 0.15)
	body.add_child(shape)

	_spawned_count += 1
	_fallback_count += 1

