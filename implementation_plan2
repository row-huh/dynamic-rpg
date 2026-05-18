# Implementation Plan - Seamless Background Grass Overlay

We will dynamically fill the gray/black area outside the `Beginning Fields` tilemap with repeating grass tiles.

## User Review Required

> [!NOTE]
> All existing collision borders, agent navigation structures, and map properties remain **100% untouched**. The outer grass is purely visual and physically inaccessible to both the player and NPCs.

---

## Proposed Changes

### [Component: Map Background]

#### [NEW] [background_grass_spawner.gd](file:///d:/court-of-whispers-godot/scripts/background_grass_spawner.gd)
Create a new GDScript attached to a node in `game.tscn` to handle the generation:
* **Automatic Detection**: Scans the `Ground` layer cells of `Beginning Fields` to find the most commonly used tile (which is the main grass tile).
* **Tiled Background Layer**: Spawns a new `TileMapLayer` child with `z_index = -10` (behind all elements) that aligns with the main map.
* **Large Bounds Filling**: Fills a `-150` to `+150` tile coordinate grid with the detected grass tile, fully covering any camera movements.

#### [MODIFY] [game.tscn](file:///d:/court-of-whispers-godot/scenes/game.tscn)
Add the `BackgroundGrassSpawner` node inside the main scene:
* Instantiate a `Node2D` named `BackgroundGrassSpawner`.
* Attach the `res://scripts/background_grass_spawner.gd` script.
* Set the `tilemap_path` property to point to `Beginning Fields`.

---

## Verification Plan

### Automated/Manual Verification
1. **Launch the Game**: Verify the game compiles and launches with zero console errors.
2. **Observe Background**: Verify that the previous gray/black background is replaced with matching seamless green grass.
3. **Verify Collisions**: Attempt to walk off the edge of the playable area and confirm that invisible boundaries still block the player and NPCs perfectly.
