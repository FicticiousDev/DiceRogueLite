# Localisation

All player-facing text lives in `localisation/strings.csv` (Godot's native CSV translations). Code, scenes and resources reference keys, never English text.

## Format
- Columns: `keys`, one column per language code (`en`, `de`, `fr`, ...), and `_notes` (ignored by Godot; translator context and placeholder lists).
- Godot imports the CSV into one `strings.<lang>.translation` per language column. Register each generated file under Project Settings > Localization > Translations (`project.godot` already lists `en`). Fallback locale is `en`.
- **Adding a language:** add a column headed with the locale code, fill it, let the editor re-import, add the new `.translation` file to the Translations list. Untranslated cells fall back to `en`.

## Key conventions
- `UPPER_SNAKE_CASE`, prefixed by area: `MENU_`, `BTN_`, `PROMPT_`, `SETTINGS_`, `HUD_`, `HINT_`, `POPUP_`, `LOG_`, `NOTE_`, `HELP_`, `DIALOG_`, ...
- **Data resources** use computed keys built from the resource `id`: `CHARACTER_<ID>_NAME`, `ENEMY_<ID>_NAME` / `_DESC`, `BIOME_<ID>_NAME`, `DIE_<ID>_NAME`, `DIE_DESIGN_<ID>_NAME`, `DIE_FINISH_<ID>_NAME`, `EQUIPMENT_<ID>_NAME`, `ABILITY_<ID>_NAME` / `_DESC`, `CHALLENGE_<ID>_DESC`. The `.tres` files no longer store text; `display_name` / `description` are getters that call `tr()`. A new resource needs its rows added to the CSV.
- **Enum-derived labels** build the key from the enum name: `TERRAIN_<NAME>`, `PIECE_<SCENE>`. Other enums map through a const dictionary of keys (`LevelData.NAMES`, `Rarity.NAMES`, `EquipmentData.SLOT_NAMES`, `HelpText.SYMBOL_NAMES`, `TurnController.STATE_NAMES`).
- **Constants hold keys**, translated at the point of use (`tr(HelpText.PLAYER_STUNNED)`). Constants cannot call `tr()`.
- **Static functions** use `TranslationServer.translate(key)`; instance code uses `tr(key)`.
- **Plurals / variants** are separate keys (`..._ONE`, `..._MANY`) chosen in code. No string concatenation of sentence fragments: use one key with `%s` / `%d` placeholders and list them in `_notes`.
- **Ability descriptions** read `Prefix: effect` and code splits on `": "`; translations must keep that separator.
- `ButtonPrompt` captions are keys (`PROMPT_SELECT`, ...).
- Scene `text` properties (Label, Button, ...) hold keys directly; Godot auto-translates them.

## Not localised
Debug-only text (debug menu, debug popups, tile debug info, `print` / `push_*` output) and the `_archived/` folder.

## Rule for future changes
Every new or changed player-facing string must go through this system: add/update the CSV row (`en` plus `_notes` for placeholders), reference the key, and never hard-code display text.
