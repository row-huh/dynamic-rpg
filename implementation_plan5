# Implementation Plan - Predefined NPC Wandering Zones

We need to restrict NPCs to wander only within specific, predefined areas of the map rather than using a simple circular radius from their spawn point.

## User Review Required

> [!IMPORTANT]
> To achieve this, I will add a custom bounding box property (`wander_zone`) to the base NPC script. 
> 
> **How it will work:**
> 1. If an NPC has a `wander_zone` defined, they will only pick random movement targets that fall strictly inside that box.
> 2. If no zone is defined, they will fall back to their current circular wandering behavior.
> 
> **I need your help with coordinates:**
> Since I cannot see the exact coordinates of the rock-fenced area in the screenshot, I will need you to walk your player to the **top-left corner** and **bottom-right corner** of the allowed area and share the coordinates with me, or I can provide you a quick script that prints your coordinates when you click so we can map out all 4 zones perfectly!

## Proposed Changes

### [MODIFY] [npc_agent.gd](file:///d:/court-of-whispers-godot/scripts/npc_agent.gd)
- Add a new exported property: `@export var wander_zone: Rect2 = Rect2()`
- Modify `_pick_next_target()`:
  - Check if `wander_zone.has_area()` is true.
  - If true, generate random `x` and `y` coordinates within the `wander_zone` bounds.
  - If false, use the existing circular `wander_radius` logic.

### [MODIFY] [game.tscn](file:///d:/court-of-whispers-godot/scenes/game.tscn)
- Define the `wander_zone` values for the 4 agents once we gather the correct coordinate boundaries for each of the 4 areas you have chosen.

## Verification Plan
1. We will launch the game and I will provide you with the exact coordinates for the first zone (Father Edran's rock fence area) using debug tools.
2. We will apply the bounding box to the Bishop instance in `game.tscn`.
3. You will verify that Father Edran never walks outside the fenced area.
4. We will repeat the coordinate gathering for the remaining 3 agents.
