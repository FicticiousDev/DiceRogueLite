class_name ButtonPrompt
extends HBoxContainer

## A button prompt: the icon of one or more actions with a caption, e.g. [A] Select. The icons follow the active device
## (keyboard, Xbox or PlayStation gamepad, see [InputMode]). Given a callable, the prompt can also be clicked.
## Use: ButtonPrompt.footer(self, ButtonPrompt.standard()) adds the usual bar along the bottom of a menu.

const ICON_SIZE: float = 34.0
const FONT_SIZE: int = 31
const TEXT_COLOR: Color = Color(0.85, 0.85, 0.9)
## Brightness of a clickable prompt under the mouse
const HOVER_TINT: Color = Color(1.25, 1.25, 1.15)

## Shown together, e.g. up and down for navigating
var actions: Array[StringName] = []
var caption: String = ""
## Called when the prompt is clicked; not clickable if empty
var on_pressed: Callable

var _icons: HBoxContainer
var _label: Label


## A prompt for [prompt_actions] (action names) captioned [text], a localisation key. Clicking it calls [pressed], if given.
static func create(prompt_actions: Array, text: String, pressed: Callable = Callable()) -> ButtonPrompt:
	var prompt := ButtonPrompt.new()
	for action in prompt_actions:
		prompt.actions.append(StringName(action))
	prompt.caption = TranslationServer.translate(text)
	prompt.on_pressed = pressed
	return prompt


## The usual prompts of a menu: navigate, select and back. A caption left empty leaves that prompt out; [extra] adds
## more as [[actions], caption] pairs.
static func standard(select: String = "PROMPT_SELECT", back: String = "PROMPT_BACK", navigate: bool = true, extra: Array = []) -> Array:
	var entries: Array = []
	if navigate:
		entries.append([[&"ui_up", &"ui_down"], "PROMPT_NAVIGATE"])
	if select != "":
		entries.append([[&"ui_accept"], select])
	entries.append_array(extra)
	if back != "":
		entries.append([[&"cancel"], back])
	return entries


## A row (or [param vertical] column) of prompts: [[actions], caption] pairs, see [method standard], each optionally with a
## third element, the callable to call when it is clicked.
static func bar(entries: Array, vertical: bool = false) -> BoxContainer:
	var box: BoxContainer = VBoxContainer.new() if vertical else HBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 12 if vertical else 48)
	for entry in entries:
		box.add_child(create(entry[0], entry[1], entry[2] if entry.size() > 2 else Callable()))
	return box


## Adds a bar of prompts along the bottom of [parent], a Control or a CanvasLayer, and returns it.
static func footer(parent: Node, entries: Array, margin: float = 28.0) -> BoxContainer:
	var box := bar(entries)
	# Anchors first: setting one moves the offsets to keep the control where it was
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = 0.0
	box.offset_right = 0.0
	box.offset_top = -margin
	box.offset_bottom = -margin
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	parent.add_child(box)
	return box


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 10)
	_icons = HBoxContainer.new()
	_icons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icons.add_theme_constant_override("separation", 2)
	add_child(_icons)
	_label = Label.new()
	_label.text = caption
	_label.add_theme_font_size_override("font_size", FONT_SIZE)
	_label.add_theme_color_override("font_color", TEXT_COLOR)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(_label)
	if on_pressed.is_valid():
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		mouse_entered.connect(func(): modulate = HOVER_TINT)
		mouse_exited.connect(func(): modulate = Color.WHITE)
		gui_input.connect(_on_gui_input)
	InputMode.device_changed.connect(_refresh)
	_refresh()


func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		accept_event()
		on_pressed.call()


## Redraws the icons for the active device.
func _refresh() -> void:
	for child in _icons.get_children():
		child.queue_free()
	for action in actions:
		var texture := InputMode.glyph(action)
		if texture:
			var icon := TextureRect.new()
			icon.texture = texture
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2.ONE * ICON_SIZE
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_icons.add_child(icon)
		else:
			_icons.add_child(_name_label(action))


## No icon for [action]: its first event as text, e.g. [Space].
func _name_label(action: StringName) -> Label:
	var label := Label.new()
	var events := InputMap.action_get_events(action) if InputMap.has_action(action) else []
	label.text = "[%s]" % events[0].as_text().get_slice(" (", 0) if events.size() > 0 else "[?]"
	label.add_theme_font_size_override("font_size", FONT_SIZE)
	label.add_theme_color_override("font_color", TEXT_COLOR)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
