extends Node2D

## Spawns StaticBody2D collision on object-layer Sprite2D props using TileSet polygons
## authored in the Fantasy Tileset .tsx files (imported by YATI).

@export var map_root_path: NodePath
@export var skip_name_substrings: Array[String] = ["Shadow"]
@export var fallback_enabled: bool = true
@export var fallback_size_scale: Vector2 = Vector2(0.5, 0.35)

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

		if not atlas.has_tile(Vector2i(0, 0)):
			continue

		var td := atlas.get_tile_data(Vector2i(0, 0), 0)
		if td == null:
			continue

		var polygons: Array = []
		var poly_count := td.get_collision_polygons_count(physics_layer)
		for poly_idx in range(poly_count):
			var pts := td.get_collision_polygon_points(physics_layer, poly_idx)
			if pts.size() < 3:
				continue
			var transformed := PackedVector2Array()
			var origin := Vector2(td.texture_origin)
			for p in pts:
				transformed.append(p + origin)
			polygons.append(transformed)

		if not polygons.is_empty():
			index[path] = polygons

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
	var polygons: Array = index.get(path, [])

	if polygons.is_empty():
		if fallback_enabled:
			_spawn_fallback(sprite)
		return

	_spawn_polygon_body(sprite, polygons)


func _spawn_polygon_body(sprite: Sprite2D, polygons: Array) -> void:
	var body := StaticBody2D.new()
	body.name = "ObjectCollision"
	body.collision_layer = PhysicsLayers.WORLD
	body.collision_mask = 0
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
	var size := tex.get_size() * sprite.scale
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
