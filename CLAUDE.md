# CLAUDE.md

Implementation follows `Dice_Roguelike_Development_Plan.md` (Obsidian vault `Game Ideas/attachments/`, also in the Claude project). Read it before starting a phase; the design lives in `Dice Game.canvas`.

# Standards

## Code
1. **Comments are concise.** Standard `##` doc comments on classes and functions. Inline comments only where something is tricky or unusual, or to keep sections organised. The developer is a professional programmer – don't explain concepts.
2. **Keep it simple.** No over-engineering, no speculative abstraction beyond what **Plan ahead** asks for. Prefer plain nodes, Resources and signals over frameworks. No manager autoload unless it has proven to be needed.
3. **Match the existing code style** of `DiceRogueLite` and `MiceAndDice`:
   - Typed GDScript (`var x: int`, `-> void`), tabs for indentation
   - `class_name` on reusable scripts, `@onready` node references, `@export` for tunables
   - Section banners for larger scripts:
     ```gdscript
     # ===========================================================================================================================================
     # Section Name
     # ===========================================================================================================================================
     ```
   - Tweens for all animation, `await` for sequencing
   - Signals up, function calls down
4. **Reuse settings and save/load from `DiceRogueLite`** – already ported in Phase 01 (`autoloads/save_manager.gd`, `saves/*.gd`, `scenes/ui/settings/*`, `scenes/ui/confirm_dialog/*`, `scenes/ui/splash/*`). Extend rather than rewrite. The original prototype is in `_archived/` for reference.

## Localisation
- **All future changes must take localisation into account.** No hard-coded player-facing text in code, scenes or `.tres` files: add a row to `localisation/strings.csv` (`en` column, placeholders listed in `_notes`) and reference the key. New data resources need their `<PREFIX>_<ID>_NAME` / `_DESC` rows. Follow `LOCALISATION.md` for key conventions, plurals and static/const handling.
- Only English is provided for now; the CSV is set up for more language columns.
- Debug-only text may stay unlocalised.

## Assets
- Placeholder texture: Godot's built-in icon (`icon.svg`, as created with every new project). Tint it with `modulate` to tell placeholders apart.
- Assets from `DiceRogueLite` and `MiceAndDice` may also be used as placeholders (UI buttons, splash images, tile highlights, `dice.glb`, grass tile art).
- Theme/setting is undecided. Never hard-code theme-specific names in code – use generic terms (player, enemy, gold, tile).

## Project
- Engine: **Godot 4.7.2** (Forward Plus, Jolt Physics), installed at `C:\Program Files\Godot_v4.7.2-stable_win64.exe`. Ask the developer before running it.
- Project name: **DiceBuilderRogueLite** (working title, will change). Location: `E:\Dev\Godot4\DiceRogueLite` – the old `DiceRogueLite` folder and repository, reused. Its previous contents are in `_archived/` (git-ignored, with a `.gdignore` so Godot skips it). Developer pushes to remote.
- Claude writes files straight into the project folder through the desktop app. **Gotcha:** re-sending a file from a staging path that was used before can deliver the earlier upload. Always stage each write under a fresh, unique path (e.g. `outputs/<timestamp>/…`) and re-read the files on disk afterwards to confirm they match. Also re-read files the developer may have edited (e.g. editor-added UIDs) before overwriting them.
- The developer allows Claude to delete files inside the project folder when needed – ask for permission at the time. If the session has no way to delete on the device, list the files for the developer to delete.
- Claude can validate scripts with a headless Linux Godot 4.7.2 in its own workspace (`--headless --import`, then run scenes with `--quit-after`). This catches parse and load errors only – the developer does the visual check.
- Resolution 1920×1080, stretch mode `canvas_items` (as `DiceRogueLite`).
