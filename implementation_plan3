# Implementation Plan - Dedicated Character-Specific NPC Scenes

We will refactor the generic, reused NPC agent blueprint into four independent, dedicated NPC scenes. This allows each character to have their own unique animations and styles, paving the way for their custom spritesheets while removing the prototype color modulate tints.

## User Review Required

> [!IMPORTANT]
> To keep the game fully functional immediately, we will create the new character scenes utilizing the existing `mira.png` and `ArmyCommanderWalk.png` frames as placeholders. 
> Whenever your teammate finishes drawing the custom Priest, Bishop, or Citizen sheets, you can simply drop the new textures into the respective scene's `AnimatedSprite2D` node within the Godot Editor in under a minute without touching any code!

---

## Proposed Changes

### [Component: NPCs & Character Scenes]

#### [NEW] [commander_npc.tscn](file:///d:/court-of-whispers-godot/scenes/npc/commander_npc.tscn)
Create the dedicated scene for the Commander NPC:
* Inherits from `CharacterBody2D` with `npc_agent.gd` script.
* Sets default `agent_id = "commander"`.
* Employs its own independent `SpriteFrames` resource for placeholder animations.

#### [NEW] [citizen_npc.tscn](file:///d:/court-of-whispers-godot/scenes/npc/citizen_npc.tscn)
Create the dedicated scene for the Citizen NPC:
* Inherits from `CharacterBody2D` with `npc_agent.gd` script.
* Sets default `agent_id = "citizen"`.
* Employs its own independent `SpriteFrames` resource.

#### [NEW] [priest_npc.tscn](file:///d:/court-of-whispers-godot/scenes/npc/priest_npc.tscn)
Create the dedicated scene for the Priest NPC:
* Inherits from `CharacterBody2D` with `npc_agent.gd` script.
* Sets default `agent_id = "priest"`.
* Employs its own independent `SpriteFrames` resource.

#### [NEW] [bishop_npc.tscn](file:///d:/court-of-whispers-godot/scenes/npc/bishop_npc.tscn)
Create the dedicated scene for the Bishop NPC:
* Inherits from `CharacterBody2D` with `npc_agent.gd` script.
* Sets default `agent_id = "bishop"`.
* Employs its own independent `SpriteFrames` resource.

#### [MODIFY] [npc_agent.gd](file:///d:/court-of-whispers-godot/scripts/npc_agent.gd)
* Remove the color modulate tint overlay logic inside `_apply_tint()` so characters render cleanly and naturally using their real sprite colors.

#### [MODIFY] [game.tscn](file:///d:/court-of-whispers-godot/scenes/game.tscn)
* Register the four new character scenes as external resources in `game.tscn`.
* Replace instances of `npc_agent.tscn` with their respective character scenes:
  * `Commander` node $\rightarrow$ `commander_npc.tscn`
  * `Citizen` node $\rightarrow$ `citizen_npc.tscn`
  * `Priest` node $\rightarrow$ `priest_npc.tscn`
  * `Bishop` node $\rightarrow$ `bishop_npc.tscn`

---

## Verification Plan

### Manual Verification
1. **Launch the Game**: Verify the game compiles and launches with zero console errors.
2. **Observe NPCs**: Verify that all four NPCs spawn in their correct positions (Commander, Citizen, Priest, Bishop) and perform their normal walking/idle routines.
3. **Verify Modulation**: Verify they are rendered in their natural red color sheets (no more color filters modulated over them).
4. **Dialogue Interactions**: Interact with each character and confirm that all dialogues trigger perfectly and retrieve the correct agent IDs.
