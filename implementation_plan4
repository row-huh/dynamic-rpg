# Implementation Plan - Refactoring Object Collision Spawner

This plan outlines the changes required to solve the issue where players/NPCs collide with random invisible shapes or empty spaces on roads and paths.

## User Review Required

> [!IMPORTANT]
> The proposed changes modify the automatic collision generation logic for map props at runtime. While this removes invalid/giant collisions and makes boundaries accurate, any prop that is intended to be solid **must** have collision polygons defined in Tiled/TSX. (Our analysis confirms all key houses, fences, and trees already have these shapes defined).

## Proposed Changes

### Map Collision Generation

#### [MODIFY] [object_collision_spawner.gd](file:///d:/court-of-whispers-godot/scripts/object_collision_spawner.gd)

* **Refactor Index Building**: Modify `_build_texture_collision_index` to scan and index *every* tile coordinate in the atlas (using `atlas.get_tiles_count()` and `atlas.get_tile_id()`) instead of only querying `Vector2i(0, 0)`.
* **Refactor Collision Lookup**: Update `_maybe_spawn_for_sprite` to:
  1. Determine the exact grid coordinate of the tile based on `sprite.region_rect` and the atlas source layout parameters (`tile_size`, `margins`, `separation`).
  2. Retrieve the specific collision polygons designed for that tile.
  3. Skip spawning fallback shapes on tiles that are present in the tileset but have no collision polygons (these are walkable details like flowers, shadows, path details, grass tufts, etc.).
* **Refactor Fallback Sizing**: Modify `_spawn_fallback` to calculate size based on `sprite.region_rect.size` if `region_enabled` is true, avoiding giant collision shapes generated from the dimensions of the entire atlas sheet.

## Verification Plan

### Automated Tests
* None.

### Manual Verification
1. Launch the Godot project in debug mode:
   ```powershell
   # We will run this to test changes
   mcp_godot_run_project
   ```
2. Enable "Visible Collision Shapes" in the editor debug settings to inspect the collision shapes at runtime.
3. Verify that:
   - Giant collision boxes no longer block paths or roads.
   - Benches, buildings, fences, and large trees retain their exact polygon collision shapes.
   - Walkable details (pebbles, shadows, flowers, grass) no longer spawn collisions.
   - Characters can move around the roads freely.
