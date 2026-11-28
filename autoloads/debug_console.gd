extends CanvasLayer

## Autoload. Developer console, debug builds only. The [code]debug_console[/code] action ([~]) opens a one-line prompt
## along the top of the screen that takes [code]debug: <command> [args][/code]; [code]quit[/code] (or Esc) closes it.
## Every command is listed in [constant COMMANDS] ([code]debug: help[/code] in game). Console and anywhere commands are
## handled here; run commands go to the handler the run sets ([method set_run_handler]). Up / Down recall earlier
## commands, Tab completes a command name. The run can also show a readout under the prompt ([method set_readout]).

## Unlocks changed: screens that show them redraw
signal progression_changed

enum Scope { CONSOLE, ANYWHERE, RUN }

const PREFIX: String = "debug:"
const QUIT: String = "quit"
## A reply starting with this is an error (shown in red, without the mark)
const ERROR_MARK: String = "!"
## Every command, in help order. [code]min[/code] / [code]max[/code] count the arguments (-1: no limit).
const COMMANDS: Array[Dictionary] = [
	{ "name": "help", "args": "[command]", "min": 0, "max": 1, "scope": Scope.CONSOLE, "group": "Console",
		"desc": "List every command, or describe one." },
	{ "name": "clear", "args": "", "min": 0, "max": 0, "scope": Scope.CONSOLE, "group": "Console",
		"desc": "Clear the console output." },

	{ "name": "unlockAll", "args": "", "min": 0, "max": 0, "scope": Scope.ANYWHERE, "group": "Unlocks & progress (anywhere)",
		"desc": "Unlock every character, die, item and die design, and save." },
	{ "name": "unlockAllCharacters", "args": "", "min": 0, "max": 0, "scope": Scope.ANYWHERE, "group": "Unlocks & progress (anywhere)",
		"desc": "Unlock every character and save. Reopen the character select to see them." },
	{ "name": "unlockAllDice", "args": "", "min": 0, "max": 0, "scope": Scope.ANYWHERE, "group": "Unlocks & progress (anywhere)",
		"desc": "Unlock every loot die (rewards, chests and shops can offer them) and save." },
	{ "name": "unlockAllItems", "args": "", "min": 0, "max": 0, "scope": Scope.ANYWHERE, "group": "Unlocks & progress (anywhere)",
		"desc": "Unlock every item and save." },
	{ "name": "unlockAllDesigns", "args": "", "min": 0, "max": 0, "scope": Scope.ANYWHERE, "group": "Unlocks & progress (anywhere)",
		"desc": "Unlock every die design and save." },
	{ "name": "unlock", "args": "<character | die | item | design> <id>", "min": 2, "max": 2, "scope": Scope.ANYWHERE, "group": "Unlocks & progress (anywhere)",
		"desc": "Unlock one character, die, item or die design and save." },
	{ "name": "lockAll", "args": "", "min": 0, "max": 0, "scope": Scope.ANYWHERE, "group": "Unlocks & progress (anywhere)",
		"desc": "Lock every character, die, item and die design again (all but those unlocked from the start), and save. Stats are kept, so a challenge already met unlocks its reward again at the next check." },
	{ "name": "lockAllCharacters", "args": "", "min": 0, "max": 0, "scope": Scope.ANYWHERE, "group": "Unlocks & progress (anywhere)",
		"desc": "Lock every character but the starting ones and save." },
	{ "name": "lockAllDice", "args": "", "min": 0, "max": 0, "scope": Scope.ANYWHERE, "group": "Unlocks & progress (anywhere)",
		"desc": "Lock every die but the starting ones and save." },
	{ "name": "lockAllItems", "args": "", "min": 0, "max": 0, "scope": Scope.ANYWHERE, "group": "Unlocks & progress (anywhere)",
		"desc": "Lock every item but the starting ones and save." },
	{ "name": "lockAllDesigns", "args": "", "min": 0, "max": 0, "scope": Scope.ANYWHERE, "group": "Unlocks & progress (anywhere)",
		"desc": "Lock every die design but the starting ones (the chosen one goes back to classic if locked) and save." },
	{ "name": "lock", "args": "<character | die | item | design> <id>", "min": 2, "max": 2, "scope": Scope.ANYWHERE, "group": "Unlocks & progress (anywhere)",
		"desc": "Lock one character, die, item or die design again and save. Ones unlocked from the start can't be locked." },
	{ "name": "resetProgress", "args": "confirm", "min": 0, "max": 1, "scope": Scope.ANYWHERE, "group": "Unlocks & progress (anywhere)",
		"desc": "Start over as a new player: wipes all stats, unlocks, banked gold and the current run (settings are kept), then goes to the main menu. Needs 'confirm'." },

	{ "name": "listCharacters", "args": "", "min": 0, "max": 0, "scope": Scope.ANYWHERE, "group": "Lists (anywhere)",
		"desc": "Character ids, and which are locked." },
	{ "name": "listDice", "args": "", "min": 0, "max": 0, "scope": Scope.ANYWHERE, "group": "Lists (anywhere)",
		"desc": "Die ids (for setDice / addDie) with their rarity, and which are locked as loot." },
	{ "name": "listItems", "args": "", "min": 0, "max": 0, "scope": Scope.ANYWHERE, "group": "Lists (anywhere)",
		"desc": "Item ids, and which are locked." },
	{ "name": "listDesigns", "args": "", "min": 0, "max": 0, "scope": Scope.ANYWHERE, "group": "Lists (anywhere)",
		"desc": "Die design ids, and which are locked." },
	{ "name": "listLevels", "args": "[type]", "min": 0, "max": 1, "scope": Scope.ANYWHERE, "group": "Lists (anywhere)",
		"desc": "Level ids by type and stage, or only those of [type]. Types: normal, challenge, boss, shop, shopBank." },
	{ "name": "listBiomes", "args": "", "min": 0, "max": 0, "scope": Scope.ANYWHERE, "group": "Lists (anywhere)",
		"desc": "Biome ids in run order, with their stage and boss level." },

	{ "name": "levelInfo", "args": "", "min": 0, "max": 0, "scope": Scope.RUN, "group": "Levels (in a run)",
		"desc": "The current level and the levels it leads to: map index, level id, type and biome." },
	{ "name": "setLevel", "args": "<level id | type> [biome id]", "min": 1, "max": 2, "scope": Scope.RUN, "group": "Levels (in a run)",
		"desc": "Replace this level (for good in the run's map) and restart it at full health. A type picks a level of it sized for the biome (boss: the biome's boss level). The biome defaults to the current one (a boss level's own biome for a boss level id)." },
	{ "name": "setNextLevels", "args": "<level id | type> [biome id]", "min": 1, "max": 2, "scope": Scope.RUN, "group": "Levels (in a run)",
		"desc": "Replace every level this one leads to, as setLevel. Each keeps its own biome unless one is given." },
	{ "name": "restart", "args": "", "min": 0, "max": 0, "scope": Scope.RUN, "group": "Levels (in a run)",
		"desc": "Restart this level at full health." },
	{ "name": "mystery", "args": "", "min": 0, "max": 0, "scope": Scope.RUN, "group": "Levels (in a run)",
		"desc": "Place a Mystery piece on this level, if anything is still locked and there isn't one." },

	{ "name": "listPool", "args": "", "min": 0, "max": 0, "scope": Scope.RUN, "group": "Dice (in a run)",
		"desc": "The dice the player has." },
	{ "name": "setDice", "args": "<die id> [die id ...]", "min": 1, "max": -1, "scope": Scope.RUN, "group": "Dice (in a run)",
		"desc": "Replace the player's dice (repeat an id for several). Raises the pool cap to fit; re-rolls if planning." },
	{ "name": "addDie", "args": "<die id> [count]", "min": 1, "max": 2, "scope": Scope.RUN, "group": "Dice (in a run)",
		"desc": "Add a die (or [count] of them) to the player's dice. Raises the pool cap to fit; re-rolls if planning." },
	{ "name": "removeDie", "args": "<die id> [count]", "min": 1, "max": 2, "scope": Scope.RUN, "group": "Dice (in a run)",
		"desc": "Take a die (or [count] of them) out of the player's dice; the last die stays. Re-rolls if planning." },
	{ "name": "reroll", "args": "", "min": 0, "max": 0, "scope": Scope.RUN, "group": "Dice (in a run)",
		"desc": "Re-roll this turn's dice (planning only)." },
	{ "name": "showcase", "args": "", "min": 0, "max": 0, "scope": Scope.RUN, "group": "Dice (in a run)",
		"desc": "Re-roll this turn with one showcase die per rarity, in the next die design each time (planning only)." },

	{ "name": "heal", "args": "", "min": 0, "max": 0, "scope": Scope.RUN, "group": "Player (in a run)",
		"desc": "Restore the player to full health." },
	{ "name": "addGold", "args": "<amount>", "min": 1, "max": 1, "scope": Scope.RUN, "group": "Player (in a run)",
		"desc": "Give the player gold (negative takes it, down to 0)." },

	{ "name": "losOverlay", "args": "", "min": 0, "max": 0, "scope": Scope.RUN, "group": "Overlays (in a run)",
		"desc": "Toggle the line of sight overlay from the planned position." },
	{ "name": "tileOverlay", "args": "", "min": 0, "max": 0, "scope": Scope.RUN, "group": "Overlays (in a run)",
		"desc": "Toggle the tile grid overlay (cell coordinates and the mouse pick)." },
	{ "name": "readout", "args": "", "min": 0, "max": 0, "scope": Scope.RUN, "group": "Overlays (in a run)",
		"desc": "Toggle the readout under the console: rolled dice, hovered cell and its path cost." },
]
## What lock / unlock take, and the Database category each is
const UNLOCK_KINDS: Dictionary[String, String] = {
	"character": "characters",
	"die": "dice",
	"item": "equipment",
	"design": "die_designs",
}
const MAIN_MENU_SCENE: String = "res://scenes/ui/main_menu/main_menu.tscn"
## Level type names the commands take, lower case
const LEVEL_TYPES: Dictionary[String, LevelData.Type] = {
	"normal": LevelData.Type.NORMAL,
	"challenge": LevelData.Type.CHALLENGE,
	"boss": LevelData.Type.BOSS,
	"shop": LevelData.Type.SHOP,
	"shopbank": LevelData.Type.SHOP_BANK,
}
## The name each level type goes by in replies
const TYPE_NAMES: Dictionary[LevelData.Type, String] = {
	LevelData.Type.NORMAL: "normal",
	LevelData.Type.CHALLENGE: "challenge",
	LevelData.Type.BOSS: "boss",
	LevelData.Type.SHOP: "shop",
	LevelData.Type.SHOP_BANK: "shopBank",
}
const COLOR_ACCENT: Color = Color(1.0, 0.45, 0.85)
const COLOR_TEXT: Color = Color(0.88, 0.88, 0.92)
const COLOR_DIM: Color = Color(0.55, 0.55, 0.62)
const COLOR_ERROR: Color = Color(1.0, 0.42, 0.38)
const FONT_SIZE: int = 20
const MAX_OUTPUT_LINES: int = 300
const MAX_OUTPUT_HEIGHT: float = 900.0
## Width of the usage column in the help
const HELP_COLUMN: int = 50
const HISTORY_SIZE: int = 50
## Where the readout sits while the console is closed: clear of the HUD's exit and settings buttons
const READOUT_CLOSED_MARGIN: Vector2 = Vector2(110, 10)
const READOUT_WIDTH: float = 760.0

var _box: VBoxContainer
var _line: LineEdit
var _output_panel: PanelContainer
var _output: RichTextLabel
var _output_lines: int = 0
var _readout_margin: MarginContainer
var _readout_panel: PanelContainer
var _readout: Label
var _run_handler: Callable
## Commands by lower-case name
var _commands: Dictionary[String, Dictionary] = {}
var _history: PackedStringArray = []
## Position in [member _history] while recalling, [code]_history.size()[/code] for the line being typed
var _history_at: int = 0


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.is_debug_build():
		set_process_input(false)
		return
	for command in COMMANDS:
		_commands[String(command.name).to_lower()] = command
	_build()
	close()


## True while the prompt is open (screens that read keys in _input skip them then).
func is_open() -> bool:
	return _line != null and _line.visible


func open() -> void:
	if not _line:
		return
	_line.visible = true
	_output_panel.visible = _output_lines > 0
	_line.text = PREFIX + " "
	_line.caret_column = _line.text.length()
	_history_at = _history.size()
	_line.grab_focus()
	_line.edit()
	_place_readout()
	_fit_output()


func close() -> void:
	if not _line:
		return
	_line.release_focus()
	_line.visible = false
	_output_panel.visible = false
	_place_readout()


## Sets who answers run commands: [param handler] takes (name: String, args: PackedStringArray) and returns the reply,
## an error if it starts with [constant ERROR_MARK]. An empty Callable (or a freed object's) means no run is going.
func set_run_handler(handler: Callable) -> void:
	_run_handler = handler


## Shows [param text] under the prompt (or at the top of the screen while it's closed); empty hides it.
func set_readout(text: String) -> void:
	if not _readout:
		return
	_readout.text = text
	_readout_panel.visible = text != ""


# ===========================================================================================================================================
# UI
# ===========================================================================================================================================


func _build() -> void:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "Courier New", "monospace"])

	_box = VBoxContainer.new()
	_box.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_theme_constant_override("separation", 0)
	add_child(_box)

	_line = LineEdit.new()
	_line.add_theme_font_override("font", font)
	_line.add_theme_font_size_override("font_size", FONT_SIZE)
	_line.add_theme_color_override("font_color", COLOR_TEXT)
	_line.add_theme_color_override("caret_color", COLOR_ACCENT)
	_line.add_theme_stylebox_override("normal", _style(Color(0.04, 0.04, 0.06, 0.96), true))
	_line.add_theme_stylebox_override("focus", _style(Color(0.04, 0.04, 0.06, 0.96), true))
	_line.placeholder_text = "debug: help"
	_line.context_menu_enabled = false
	_line.keep_editing_on_text_submit = true
	_line.text_submitted.connect(_submit)
	_box.add_child(_line)

	_output_panel = PanelContainer.new()
	_output_panel.add_theme_stylebox_override("panel", _style(Color(0.04, 0.04, 0.06, 0.88), false))
	_box.add_child(_output_panel)
	_output = RichTextLabel.new()
	_output.bbcode_enabled = true
	_output.scroll_following = true
	_output.selection_enabled = true
	_output.focus_mode = Control.FOCUS_NONE
	_output.add_theme_font_override("normal_font", font)
	_output.add_theme_font_override("bold_font", font)
	_output.add_theme_font_size_override("normal_font_size", FONT_SIZE - 2)
	_output.add_theme_font_size_override("bold_font_size", FONT_SIZE - 2)
	_output.add_theme_color_override("default_color", COLOR_TEXT)
	_output_panel.add_child(_output)

	_readout_margin = MarginContainer.new()
	_readout_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.add_child(_readout_margin)
	_readout_panel = PanelContainer.new()
	_readout_panel.add_theme_stylebox_override("panel", _style(Color(0.06, 0.06, 0.09, 0.85), false))
	_readout_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_readout_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_readout_panel.visible = false
	_readout_margin.add_child(_readout_panel)
	_readout = Label.new()
	_readout.custom_minimum_size.x = READOUT_WIDTH
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_readout.add_theme_font_override("font", font)
	_readout.add_theme_font_size_override("font_size", FONT_SIZE - 4)
	_readout.add_theme_color_override("font_color", COLOR_TEXT)
	_readout_panel.add_child(_readout)


func _style(color: Color, underline: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_content_margin_all(8)
	style.content_margin_left = 14
	if underline:
		style.border_color = Color(COLOR_ACCENT, 0.7)
		style.border_width_bottom = 2
	return style


## Sizes the output to its text, up to [constant MAX_OUTPUT_HEIGHT] (it scrolls beyond that).
func _fit_output() -> void:
	# The content height is only known once the text has been laid out
	await get_tree().process_frame
	_output.custom_minimum_size.y = minf(_output.get_content_height(), MAX_OUTPUT_HEIGHT)


## The readout goes under the console, or clear of the HUD buttons while it's closed.
func _place_readout() -> void:
	var margin := Vector2.ZERO if is_open() else READOUT_CLOSED_MARGIN
	_readout_margin.add_theme_constant_override("margin_left", int(margin.x))
	_readout_margin.add_theme_constant_override("margin_top", int(margin.y))


func _print(text: String, color: Color = COLOR_TEXT) -> void:
	for line in text.split("\n"):
		_output.push_color(color)
		_output.add_text(line)
		_output.pop()
		_output.newline()
		_output_lines += 1
	while _output_lines > MAX_OUTPUT_LINES:
		_output.remove_paragraph(0)
		_output_lines -= 1
	_output_panel.visible = is_open()
	_fit_output()


func _clear_output() -> void:
	_output.clear()
	_output_lines = 0
	_output_panel.visible = false


# ===========================================================================================================================================
# Input
# ===========================================================================================================================================


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_console") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if is_open():
			close()
		else:
			open()
		return
	if not is_open() or not (event is InputEventKey) or not event.pressed:
		return
	match event.keycode:
		KEY_ESCAPE:
			close()
		KEY_UP:
			_recall(-1)
		KEY_DOWN:
			_recall(1)
		KEY_TAB:
			_complete()
		_:
			return
	get_viewport().set_input_as_handled()


## Steps through earlier commands; past the newest is an empty prompt.
func _recall(step: int) -> void:
	if _history.is_empty():
		return
	_history_at = clampi(_history_at + step, 0, _history.size())
	_line.text = _history[_history_at] if _history_at < _history.size() else PREFIX + " "
	_line.caret_column = _line.text.length()


## Completes the command name being typed, or lists the candidates if there are several.
func _complete() -> void:
	var text := _line.text.strip_edges()
	if not text.to_lower().begins_with(PREFIX):
		return
	var typed := text.substr(PREFIX.length()).strip_edges().to_lower()
	# Names only, not arguments
	if typed.contains(" "):
		return
	var matches: Array[String] = []
	for key in _commands:
		if key.begins_with(typed):
			matches.append(_commands[key].name)
	if matches.size() == 1:
		_line.text = "%s %s " % [PREFIX, matches[0]]
		_line.caret_column = _line.text.length()
	elif matches.size() > 1:
		_print("  ".join(matches), COLOR_DIM)


func _remember(text: String) -> void:
	if _history.is_empty() or _history[-1] != text:
		_history.append(text)
	if _history.size() > HISTORY_SIZE:
		_history.remove_at(0)
	_history_at = _history.size()


# ===========================================================================================================================================
# Commands
# ===========================================================================================================================================


func _submit(text: String) -> void:
	text = text.strip_edges()
	_line.text = PREFIX + " "
	_line.caret_column = _line.text.length()
	if text == "" or text.to_lower() == PREFIX:
		return
	_remember(text)
	if text.to_lower() == QUIT:
		close()
		return
	_print("> " + text, COLOR_DIM)
	if not text.to_lower().begins_with(PREFIX):
		_error("Commands start with '%s', e.g. '%s help'. '%s' closes the console." % [PREFIX, PREFIX, QUIT])
		return
	var parts := text.substr(PREFIX.length()).strip_edges().split(" ", false)
	var command: Dictionary = _commands.get(parts[0].to_lower(), {})
	if command.is_empty():
		_error("Unknown command '%s'. '%s help' lists them." % [parts[0], PREFIX])
		return
	var args := parts.slice(1)
	if args.size() < command.min or (command.max != -1 and args.size() > command.max):
		_error("Usage: %s" % _usage(command))
		return
	var reply := _execute(command, args)
	if reply.begins_with(ERROR_MARK):
		_error(reply.substr(ERROR_MARK.length()))
	elif reply != "":
		_print(reply)


func _error(text: String) -> void:
	_print(text, COLOR_ERROR)


func _execute(command: Dictionary, args: PackedStringArray) -> String:
	match command.scope:
		Scope.RUN:
			if not _run_handler.is_valid():
				return ERROR_MARK + "Only during a run."
			return _run_handler.call(command.name, args)
		Scope.ANYWHERE:
			return _anywhere(command.name, args)
	match command.name:
		"help":
			return _help(args)
		"clear":
			_clear_output()
	return ""


func _usage(command: Dictionary) -> String:
	return ("%s %s %s" % [PREFIX, command.name, command.args]).strip_edges()


## Every command, by group, or the one named in [param args].
func _help(args: PackedStringArray) -> String:
	if args.size() > 0:
		var command: Dictionary = _commands.get(args[0].to_lower(), {})
		if command.is_empty():
			return ERROR_MARK + "Unknown command '%s'." % args[0]
		return "%s\n  %s" % [_usage(command), command.desc]
	var lines := PackedStringArray()
	var group := ""
	for command in COMMANDS:
		if command.group != group:
			group = command.group
			lines.append("%s-- %s --" % ["" if lines.is_empty() else "\n", group])
		lines.append("%s %s" % [_usage(command).rpad(HELP_COLUMN), command.desc])
	lines.append("\n%s %s" % [QUIT.rpad(HELP_COLUMN), "Close the console (as Esc or [~] do). Up / Down recall commands, Tab completes a name."])
	return "\n".join(lines)


func _anywhere(command: String, args: PackedStringArray) -> String:
	var progression := SaveManager.progression_data
	match command:
		"unlockAll":
			progression.unlock_all()
			return _unlocked("Unlocked every character, die, item and die design.")
		"unlockAllCharacters":
			progression.unlock_all_characters()
			return _unlocked("Unlocked every character.")
		"unlockAllDice":
			progression.unlock_all_dice()
			return _unlocked("Unlocked every die.")
		"unlockAllItems":
			progression.unlock_all_items()
			return _unlocked("Unlocked every item.")
		"unlockAllDesigns":
			progression.unlock_all_designs()
			return _unlocked("Unlocked every die design.")
		"unlock", "lock":
			return _set_unlocked(args, command == "unlock")
		"lockAll":
			progression.lock_all()
			return _unlocked("Locked every character, die, item and die design not unlocked from the start.")
		"lockAllCharacters":
			progression.lock_all_characters()
			return _unlocked("Locked every character not unlocked from the start.")
		"lockAllDice":
			progression.lock_all_dice()
			return _unlocked("Locked every die not unlocked from the start.")
		"lockAllItems":
			progression.lock_all_items()
			return _unlocked("Locked every item not unlocked from the start.")
		"lockAllDesigns":
			progression.lock_all_designs()
			return _unlocked("Locked every die design but the starting ones.")
		"resetProgress":
			if args.size() == 0 or args[0].to_lower() != "confirm":
				return ERROR_MARK + "This wipes all progress and the current run. Type '%s resetProgress confirm' to go ahead." % PREFIX
			_reset_progress()
			return "Progress reset: you're a new player. Going to the main menu."
		"listCharacters":
			var characters := Database.get_all("characters")
			characters.sort_custom(func(a: CharacterData, b: CharacterData): return a.order < b.order)
			return "\n".join(characters.map(func(c: CharacterData):
				return String(c.id) + ("" if progression.is_character_unlocked(c) else "  (locked)")))
		"listDice":
			var dice := Database.get_all("dice")
			dice.sort_custom(func(a: DieType, b: DieType): return a.rarity < b.rarity if a.rarity != b.rarity else String(a.id) < String(b.id))
			return "\n".join(dice.map(func(t: DieType):
				return "%s %s%s" % [String(t.id).rpad(24), Rarity.display_name(t.rarity), "" if not t.loot or progression.is_die_unlocked(t) else "  (locked)"]))
		"listItems":
			var items := Database.get_all("equipment")
			items.sort_custom(func(a: EquipmentData, b: EquipmentData): return String(a.id) < String(b.id))
			return "\n".join(items.map(func(item: EquipmentData):
				return String(item.id) + ("" if progression.is_item_unlocked(item) else "  (locked)")))
		"listDesigns":
			var designs := ProgressionData.sorted_by_order(Database.get_all("die_designs"), ProgressionData.DIE_DESIGN_ORDER)
			return "\n".join(designs.map(func(design: DieDesign):
				return String(design.id) + ("" if progression.is_design_unlocked(design) else "  (locked)")))
		"listLevels":
			return _list_levels(args)
		"listBiomes":
			var biomes := Database.get_all("biomes")
			biomes.sort_custom(func(a: BiomeData, b: BiomeData): return a.order < b.order)
			return "\n".join(biomes.map(func(b: BiomeData):
				return "%s order %d, stage %d, boss level %s" % [String(b.id).rpad(12), b.order, b.stage(), b.boss_level]))
	return ""


## lock / unlock [code]<kind> <id>[/code] ([param unlocked] for unlock).
func _set_unlocked(args: PackedStringArray, unlocked: bool) -> String:
	var kind := args[0].to_lower()
	if not UNLOCK_KINDS.has(kind):
		return ERROR_MARK + "Unknown kind '%s'. Kinds: %s." % [args[0], ", ".join(PackedStringArray(UNLOCK_KINDS.keys()))]
	var category := UNLOCK_KINDS[kind]
	var content := Database.get_content(category, StringName(args[1].to_lower()))
	if not content:
		return ERROR_MARK + "No %s '%s'." % [kind, args[1]]
	if not unlocked and content.starts_unlocked:
		return ERROR_MARK + "%s '%s' is unlocked from the start." % [kind.capitalize(), content.id]
	SaveManager.progression_data.set_unlocked(category, content.id, unlocked)
	return _unlocked("%s %s '%s'." % ["Unlocked" if unlocked else "Locked", kind, content.id])


## Wipes the save back to a new player's and reloads the main menu, so nothing on screen holds the old run. The tree
## is paused until then, so the run in progress can't write to the fresh save.
func _reset_progress() -> void:
	set_readout("")
	get_tree().paused = true
	SaveManager.reset_progress()
	progression_changed.emit()
	await SceneManager.change_scene(MAIN_MENU_SCENE)
	get_tree().paused = false


## Saves the unlocks and lets screens showing them redraw.
func _unlocked(reply: String) -> String:
	SaveManager.save_data()
	progression_changed.emit()
	return reply


func _list_levels(args: PackedStringArray) -> String:
	var only := -1
	if args.size() > 0:
		if not LEVEL_TYPES.has(args[0].to_lower()):
			return ERROR_MARK + "Unknown level type '%s'. Types: %s." % [args[0], ", ".join(type_names())]
		only = LEVEL_TYPES[args[0].to_lower()]
	# "type:stage" -> level ids
	var groups: Dictionary[String, PackedStringArray] = {}
	var levels := Database.get_all("levels")
	levels.sort_custom(func(a: LevelData, b: LevelData): return String(a.id) < String(b.id))
	for level: LevelData in levels:
		if only == -1 or level.type == only:
			var key := "%s, stage %d" % [type_name(level.type), level.stage] if level.stage > 0 else type_name(level.type)
			if not groups.has(key):
				groups[key] = PackedStringArray()
			groups[key].append(String(level.id))
	var lines := PackedStringArray()
	for key in groups:
		lines.append("%s: %s" % [key, ", ".join(groups[key])])
	return "\n".join(lines) if lines.size() > 0 else "No levels."


## The name commands use for [param type] (see [constant LEVEL_TYPES]).
func type_name(type: LevelData.Type) -> String:
	return TYPE_NAMES[type]


func type_names() -> PackedStringArray:
	return PackedStringArray(TYPE_NAMES.values())
