class_name ActionList
extends PanelContainer

## Side panel listing the planned actions. Click an entry to rewind to it, edit it or delete it.

signal rewind_requested(index: int)
signal edit_requested(index: int)
signal delete_requested(index: int)
signal commit_pressed
signal ability_pressed

enum Option { REWIND, EDIT, DELETE }

@onready var header: Label = %Header
@onready var hint: Label = %Hint
@onready var entries: VBoxContainer = %Entries
@onready var commit_button: Button = %CommitButton
@onready var ability_button: Button = %AbilityButton
@onready var menu: PopupMenu = %EntryMenu

var _menu_index: int = -1
var _lines: Array[String] = []
var _warnings: Array[String] = []
var _log_from: int = -1
var _interactive: bool = true
var _editing: int = -1


func _ready() -> void:
	commit_button.pressed.connect(commit_pressed.emit)
	ability_button.pressed.connect(ability_pressed.emit)
	menu.add_item("Rewind to here", Option.REWIND)
	menu.add_item("Edit", Option.EDIT)
	menu.add_item("Delete", Option.DELETE)
	menu.id_pressed.connect(_on_menu_id_pressed)


## Rebuilds the entries. [warnings] (one per line, "" for none) show under their entry; [editing] marks the
## slot being edited (-1 for none). Lines from [log_from] on are read-only log entries (enemy attacks);
## planned actions can only be clicked while [interactive].
func show_actions(lines: Array[String], warnings: Array[String], editing: int = -1, log_from: int = -1, interactive: bool = true) -> void:
	if lines == _lines and warnings == _warnings and editing == _editing and log_from == _log_from and interactive == _interactive:
		return
	var previous := _lines.size()
	_lines = lines.duplicate()
	_warnings = warnings.duplicate()
	_editing = editing
	_log_from = log_from
	_interactive = interactive
	for child in entries.get_children():
		child.queue_free()
	for i in lines.size():
		var entry := VBoxContainer.new()
		var button := Button.new()
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 22)
		# Wrap rather than widen the panel
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.x = 1
		button.text = "%d.  %s" % [i + 1, lines[i]]
		if log_from != -1 and i >= log_from:
			button.text = "»  " + lines[i]
			button.flat = true
			button.disabled = true
			button.add_theme_color_override("font_disabled_color", Color(1.0, 0.55, 0.45))
		elif i == editing:
			button.text += "   (editing)"
			button.modulate = Color(1.0, 0.85, 0.4)
			button.disabled = true
		elif not interactive:
			button.disabled = true
		button.pressed.connect(_open_menu.bind(i, button))
		entry.add_child(button)
		if warnings[i] != "":
			var label := Label.new()
			label.text = "!  " + warnings[i]
			label.add_theme_font_size_override("font_size", 16)
			label.add_theme_color_override("font_color", Color(1.0, 0.7, 0.25))
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			entry.add_child(label)
		entries.add_child(entry)
		# New entries pop in
		if i >= previous:
			entry.pivot_offset_ratio = Vector2(0.5, 0.5)
			entry.scale = Vector2(0.6, 0.6)
			create_tween().tween_property(entry, "scale", Vector2.ONE, Anim.t(0.3)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


## Docks the panel on the left or right edge of the screen.
func set_side(left: bool) -> void:
	var width := offset_right - offset_left
	anchor_left = 0.0 if left else 1.0
	anchor_right = anchor_left
	# Grow away from the screen edge if the content ever needs more room
	grow_horizontal = Control.GROW_DIRECTION_END if left else Control.GROW_DIRECTION_BEGIN
	offset_left = 20.0 if left else -20.0 - width
	offset_right = offset_left + width


func set_header(text: String) -> void:
	header.text = text


func set_hint(text: String) -> void:
	hint.text = text


## The character's active ability: label, tooltip, whether it can be pressed, and whether it's armed.
func set_ability(text: String, tooltip: String, enabled: bool, armed: bool) -> void:
	ability_button.visible = true
	ability_button.text = text
	ability_button.tooltip_text = tooltip
	ability_button.disabled = not enabled
	ability_button.modulate = Color(1.0, 0.8, 0.35) if armed else Color.WHITE


func set_commit_enabled(enabled: bool) -> void:
	commit_button.disabled = not enabled


func _open_menu(index: int, button: Button) -> void:
	_menu_index = index
	menu.position = Vector2i(button.get_screen_position() + Vector2(0, button.size.y))
	menu.popup()


func _on_menu_id_pressed(id: int) -> void:
	match id:
		Option.REWIND:
			rewind_requested.emit(_menu_index)
		Option.EDIT:
			edit_requested.emit(_menu_index)
		Option.DELETE:
			delete_requested.emit(_menu_index)
