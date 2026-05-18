# Game HUD Redesign: Slide-out Drawer

We will completely overhaul the top-left `GameHUD` to use your custom `assets/ui/top_left_ui.PNG` asset and implement a top-down slide-out mechanism so it doesn't permanently obscure the screen.

## Proposed Changes

### 1. Scene Layout (`scenes/ui/game_ui.tscn`)
- **[MODIFY] `GameHUD` Structure**
  - Change the root `GameHUD` node to act as the moving container. We will anchor it to the top-left but allow its Y-position to move.
  - Set the background of the HUD to a `TextureRect` using `assets/ui/top_left_ui.PNG`.
  - Re-parent and manually position all 6 `ProgressBar`s, `DayLabel`, `TurnsLabel`, and `QuestLabel` using absolute coordinates (`offset_top`, `offset_left`) so they perfectly align with the drawn elements in your new background image.
  - Change the progress bars to use `StyleBoxFlat` overrides so they blend cleanly (removing generic grey backgrounds).

- **[NEW] Toggle Button**
  - Add a small `Button` (or `TextureButton`) anchored securely to the top-left corner of the screen. This button will remain visible at all times and will act as the toggle switch for the drawer.

### 2. Animation Logic (`scripts/game_ui.gd`)
- **[MODIFY] `game_ui.gd`**
  - Add a new boolean state `_is_drawer_open = false`.
  - Connect the new toggle button's `pressed` signal to a new `_on_drawer_toggle_pressed()` function.
  - Implement a smooth animation using Godot 4's `Tween` system. When the button is pressed, the HUD will smoothly slide down into view (`position.y` animates to `0`), and when pressed again, it will slide back up off-screen (`position.y` animates to `-400` or whatever the height of the image is).
  - All existing functionality in `game_hud.gd` that updates the bars will remain exactly the same since we are keeping the node names identical.

## Open Questions

> [!IMPORTANT]
> **Toggle Button Appearance**: Do you have an icon image you want to use for the "Open Stats" button, or should I just use a simple button with text like "Stats / Quests" for now?

> [!NOTE]
> Since the exact placement of the bars over your image requires precise pixel pushing, I will make my best educated guess on coordinates. After implementation, if any bar is slightly misaligned with your drawing, I can easily nudge them by a few pixels based on your feedback.

## Verification Plan
1. Restart the Godot project.
2. Verify the HUD starts hidden off-screen with only the toggle button visible.
3. Click the toggle button to ensure the HUD smoothly slides down.
4. Verify all 6 bars and text elements correctly align over the background image and update as turns pass.
