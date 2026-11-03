class_name DebugMenu
extends Control

## Developer tools, hidden until opened with the DEBUG button or [F1] (debug builds only). A command's shortcut key
## only works while the menu is open, so they can't be pressed by accident in play. Commands go up through
## [signal command]; the run feeds back what's available ([method set_enabled]), toggle states and the debug readout.

signal command(id: Command)

enum Command { REROLL, SHOWCASE, RESTART, SHOP_HERE, NEXT_SHOP, NEXT_SHOP_BANK, MYSTERY, LINE_OF_SIGHT, GRID }

const LABELS: Dictionary[Command, String] = {
	Command.REROLL: "Re-roll dice",
	Command.SHOWCASE: "Showcase dice (one per rarity)",
	Command.RESTART: "Restart level (full health)",
	Command.SHOP_HERE: "This level → Shop & Bank (+100 gold)",
	Command.NEXT_SHOP: "Next levels → Shop",
	Command.NEXT_SHOP_BANK: "Next levels → Shop & Bank",
	Command.MYSTERY: "Place a Mystery piece",
	Command.LINE_OF_SIGHT: "Line of sight",
	Command.GRID: "Grid overlay",
}
## Shortcut actions, live only while the menu is open
const ACTIONS: Dictionary[Command, StringName] = {
	Command.REROLL: &"debug_roll",
	Command.SHOWCASE: &"debug_roll_showcase",
	Command.RESTART: &"debug_rebuild",
	Command.SHOP_HERE: &"debug_shop",
	Command.MYSTERY: &"debug_unlock",
	Command.LINE_OF_SIGHT: &"debug_los",
	Command.GRID: &"debug_grid",
}
const TOGGLES: Array[Command] = [Command.LINE_OF_SIGHT, Command.GRID]
const TOP: float = 60.0
const WIDTH: float = 400.0
const ACCENT: Color = Color(1.0, 0.45, 0.85)

var _open_button: Button
var _panel: PanelContainer
var _buttons: Dictionary[Command, BaseButton] = {}
var _info: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not OS.is_debug_build():
		visible = false
		set_process_unhandled_input(false)
		return

	_open_button = Button.new()
	_open_button.text = "DEBUG"
	_open_button.focus_mode = Control.FOCUS_NONE
	_open_button.add_theme_font_size_override("font_size", 16)
	_open_button.position = Vector2(110, 14)
	_open_button.size = Vector2(80, 32)
	_open_button.modulate = Color(1, 1, 1, 0.55)
	_open_button.pressed.connect(toggle)
	add_child(_open_button)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.94)
	style.border_color = Color(ACCENT, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.visible = false
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_panel.add_child(box)

	var title := Label.new()
	title.text = "DEBUG  [%s]" % _key_text(&"debug_menu")
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", ACCENT)
	box.add_child(title)
	for id: Command in LABELS:
		var button: Button = CheckButton.new() if id in TOGGLES else Button.new()
		button.text = LABELS[id]
		if ACTIONS.has(id):
			button.text += "   [%s]" % _key_text(ACTIONS[id])
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.focus_mode = Control.FOCUS_NONE
		button.add_theme_font_size_override("font_size", 18)
		button.pressed.connect(func(): command.emit(id))
		box.add_child(button)
		_buttons[id] = button
	box.add_child(HSeparator.new())
	_info = Label.new()
	_info.custom_minimum_size.x = WIDTH - 24.0
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.add_theme_font_size_override("font_size", 15)
	_info.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85))
	box.add_child(_info)
	set_side(true)


func is_open() -> bool:
	return _panel != null and _panel.visible


func toggle() -> void:
	if _panel:
		_panel.visible = not _panel.visible
		_open_button.modulate.a = 1.0 if _panel.visible else 0.55


## Docks the panel on the left or right edge, under the HUD buttons.
func set_side(left: bool) -> void:
	if not _panel:
		return
	var screen_width := get_viewport_rect().size.x
	_panel.position = Vector2(20.0 if left else screen_width - 20.0 - WIDTH, TOP)
	_panel.custom_minimum_size.x = WIDTH


## The command whose shortcut [event] presses, or -1. Only while the menu is open.
func command_for(event: InputEvent) -> int:
	if not is_open():
		return -1
	for id: Command in ACTIONS:
		if event.is_action_pressed(ACTIONS[id]):
			return id
	return -1


func set_enabled(id: Command, enabled: bool) -> void:
	_buttons[id].disabled = not enabled


func set_toggled(id: Command, on: bool) -> void:
	_buttons[id].set_pressed_no_signal(on)


func set_info(text: String) -> void:
	_info.text = text


static func _key_text(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			return OS.get_keycode_string(event.physical_keycode)
	return "?"
