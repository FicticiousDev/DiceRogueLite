extends Node

## Autoload. Tracks the active input device (keyboard and mouse, or gamepad) and the kind of gamepad, and makes the game playable
## on a gamepad:
##  - In levels (no menu open) the left stick or d-pad moves the mouse cursor, and A clicks. Everything that reacts to the mouse
##    (tile and die picking, hovering, buttons) works unchanged.
##  - Menus register with [method register_menu]. While one is open, the stick or d-pad (and the arrow keys) step the focus
##    from control to control, looping at the ends, and A presses the focused one.
##  - [method glyph] gives the icon for an action on the active device, for [ButtonPrompt].
## B / Circle is the [code]cancel[/code] action (as Esc and right-click are), Back / View the [code]map[/code] action.

signal device_changed

enum Device { KEYBOARD, GAMEPAD }
enum Pad { XBOX, PLAYSTATION }
## Which glyph set the player wants: follow the connected controller, or always one of the two
enum PadScheme { AUTO, XBOX, PLAYSTATION }

const GLYPHS: String = "res://assets/ui/input/"
## Cursor speed in viewport pixels per second at full stick, and the share of it while the left trigger is held
const CURSOR_SPEED: float = 1000.0
const CURSOR_SLOW: float = 0.3
const STICK_DEADZONE: float = 0.25
## Stick deflection that steps the focus
const NAV_THRESHOLD: float = 0.6
## Seconds before a held direction repeats, then between repeats
const NAV_DELAY: float = 0.4
const NAV_INTERVAL: float = 0.12
## Pixels the real mouse may differ from the virtual cursor before it counts as the player moving the mouse
const MOUSE_TOLERANCE: float = 4.0
## Actions with no gamepad event of their own whose prompt shows another action's glyph instead (the cursor clicks for them)
const GAMEPAD_ALIASES: Dictionary = {&"select": &"ui_accept"}
const DIRECTIONS: Dictionary = {
	&"ui_up": Vector2.UP,
	&"ui_down": Vector2.DOWN,
	&"ui_left": Vector2.LEFT,
	&"ui_right": Vector2.RIGHT,
}

var device: Device = Device.KEYBOARD
var pad: Pad = Pad.XBOX
var pad_scheme: PadScheme = PadScheme.AUTO

var _pad_id: int = 0
## The virtual cursor in viewport pixels
var _cursor: Vector2 = Vector2.ZERO
## True while a click is being fed to the viewport, so it isn't mistaken for the mouse
var _synthesizing: bool = false
## Registered menus: root node -> { entry, cancel, navigate }
var _menus: Dictionary = {}
## Open menus, the one on top last
var _stack: Array[Node] = []
## The focused control of a menu when another opened over it
var _saved_focus: Dictionary = {}
var _held: Vector2 = Vector2.ZERO
var _held_time: float = 0.0
var _textures: Dictionary = {}
## Menus whose root has no visibility_changed signal, checked every frame
var _polled: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var pads := Input.get_connected_joypads()
	if pads.size() > 0:
		_pad_id = pads[0]
		pad = _pad_type(_pad_id)


# ===========================================================================================================================================
# Device
# ===========================================================================================================================================


## True while the gamepad is the active device.
func is_gamepad() -> bool:
	return device == Device.GAMEPAD


## True while the stick moves the cursor: gamepad in use and no registered menu open.
func cursor_mode() -> bool:
	return device == Device.GAMEPAD and _active() == null


## Sets the glyph scheme (see [enum PadScheme]); prompts change at once.
func set_pad_scheme(scheme: PadScheme) -> void:
	pad_scheme = scheme
	var new_pad := _pad_type(_pad_id)
	if new_pad != pad:
		pad = new_pad
		device_changed.emit()


func _pad_type(id: int) -> Pad:
	if pad_scheme == PadScheme.XBOX:
		return Pad.XBOX
	if pad_scheme == PadScheme.PLAYSTATION:
		return Pad.PLAYSTATION
	var joy_name := Input.get_joy_name(id).to_lower()
	for word in ["playstation", "ps3", "ps4", "ps5", "dualshock", "dualsense", "sony"]:
		if joy_name.contains(word):
			return Pad.PLAYSTATION
	return Pad.XBOX


## Switches to the device [event] came from. True if the device (or kind of gamepad) changed.
func _track_device(event: InputEvent) -> bool:
	var new_device := device
	var new_pad := pad
	if event is InputEventMouseMotion:
		# The motion from warping the pointer to the virtual cursor isn't the player's mouse
		if device == Device.GAMEPAD and event.position.distance_to(_cursor) < MOUSE_TOLERANCE:
			return false
		new_device = Device.KEYBOARD
	elif event is InputEventMouseButton or event is InputEventKey:
		new_device = Device.KEYBOARD
	elif event is InputEventJoypadButton or (event is InputEventJoypadMotion and absf(event.axis_value) > 0.5):
		new_device = Device.GAMEPAD
		_pad_id = event.device
		new_pad = _pad_type(event.device)
	if new_device == device and new_pad == pad:
		return false
	var was_gamepad := device == Device.GAMEPAD
	device = new_device
	pad = new_pad
	if device == Device.GAMEPAD:
		_cursor = get_viewport().get_mouse_position()
		_held = Vector2.ZERO
		_focus_active.call_deferred()
	elif was_gamepad and (event is InputEventMouseMotion or event is InputEventMouseButton):
		_release_focus()
	_apply_mouse_mode()
	device_changed.emit()
	return true


func _apply_mouse_mode() -> void:
	var hidden := device == Device.GAMEPAD and _active() != null
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN if hidden else Input.MOUSE_MODE_VISIBLE


func _release_focus() -> void:
	var focus := get_viewport().gui_get_focus_owner()
	if focus:
		focus.release_focus()


# ===========================================================================================================================================
# Input
# ===========================================================================================================================================


func _input(event: InputEvent) -> void:
	if _synthesizing:
		return
	if _track_device(event):
		return
	if device == Device.GAMEPAD:
		if cursor_mode():
			if event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A:
				_click(event.pressed)
				get_viewport().set_input_as_handled()
		elif _is_direction(event):
			# Stepped from _process, with repeat; the built-in focus movement would double it
			get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and _active() != null:
		for action in DIRECTIONS:
			if event.is_action_pressed(action, true):
				if _navigate(DIRECTIONS[action]):
					get_viewport().set_input_as_handled()
				return


## Menus that don't handle [code]cancel[/code] themselves get their cancel callable called.
func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("cancel"):
		return
	var root := _active()
	if root == null:
		return
	var cancel: Callable = _menus[root].cancel
	if cancel.is_valid():
		get_viewport().set_input_as_handled()
		cancel.call()


func _is_direction(event: InputEvent) -> bool:
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return false
	for action in DIRECTIONS:
		if event.is_action(action):
			return true
	return false


func _process(delta: float) -> void:
	for root in _polled.duplicate():
		_refresh_menu(root)
	if device != Device.GAMEPAD:
		return
	if cursor_mode():
		_release_focus()
		_held = Vector2.ZERO
		_move_cursor(delta)
	else:
		_step_focus(delta)
	_apply_mouse_mode()


func _stick() -> Vector2:
	var stick := Vector2(Input.get_joy_axis(_pad_id, JOY_AXIS_LEFT_X), Input.get_joy_axis(_pad_id, JOY_AXIS_LEFT_Y))
	var length := stick.length()
	if length < STICK_DEADZONE:
		return Vector2.ZERO
	return stick.normalized() * minf((length - STICK_DEADZONE) / (1.0 - STICK_DEADZONE), 1.0)


func _dpad() -> Vector2:
	var result := Vector2.ZERO
	if Input.is_joy_button_pressed(_pad_id, JOY_BUTTON_DPAD_UP):
		result.y -= 1.0
	if Input.is_joy_button_pressed(_pad_id, JOY_BUTTON_DPAD_DOWN):
		result.y += 1.0
	if Input.is_joy_button_pressed(_pad_id, JOY_BUTTON_DPAD_LEFT):
		result.x -= 1.0
	if Input.is_joy_button_pressed(_pad_id, JOY_BUTTON_DPAD_RIGHT):
		result.x += 1.0
	return result


# ===========================================================================================================================================
# Cursor
# ===========================================================================================================================================


func _move_cursor(delta: float) -> void:
	var move := _stick() + _dpad()
	if move == Vector2.ZERO:
		return
	var speed := CURSOR_SPEED
	if Input.get_joy_axis(_pad_id, JOY_AXIS_TRIGGER_LEFT) > 0.3:
		speed *= CURSOR_SLOW
	var screen := get_viewport().get_visible_rect()
	_cursor = (_cursor + move.limit_length(1.0) * speed * delta).clamp(screen.position, screen.end - Vector2.ONE)
	get_viewport().warp_mouse(_cursor)


## A left click at the cursor, pressed or released.
func _click(pressed: bool) -> void:
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = pressed
	click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	click.position = _cursor
	click.global_position = _cursor
	_synthesizing = true
	get_viewport().push_input(click, true)
	_synthesizing = false


# ===========================================================================================================================================
# Menus
# ===========================================================================================================================================


## Registers a menu: [param root] is the node whose visibility opens and closes it (a CanvasLayer or Control). While it is open
## (the most recently opened one wins) the focus loops through its controls. [param entry] returns the control to focus first
## (default: the first one). [param cancel] is called on [code]cancel[/code] if nothing else handled it. [param navigate] is
## called with the direction first and returns true if it moved things itself.
func register_menu(root: Node, entry: Callable = Callable(), cancel: Callable = Callable(), navigate: Callable = Callable()) -> void:
	_menus[root] = {"entry": entry, "cancel": cancel, "navigate": navigate}
	root.tree_exiting.connect(_forget_menu.bind(root))
	if root.has_signal(&"visibility_changed"):
		root.connect(&"visibility_changed", _refresh_menu.bind(root))
	else:
		_polled.append(root)
	_refresh_menu.call_deferred(root)


func _forget_menu(root: Node) -> void:
	_menus.erase(root)
	_polled.erase(root)
	_close_menu(root)


func _is_open(root: Node) -> bool:
	if not is_instance_valid(root) or not root.is_inside_tree() or root.is_queued_for_deletion():
		return false
	if root is CanvasLayer:
		return root.visible
	if root is Control:
		return root.is_visible_in_tree()
	return true


func _refresh_menu(root: Node) -> void:
	if not _menus.has(root):
		return
	if _is_open(root):
		if _stack.has(root):
			return
		var below := _active()
		if below:
			_saved_focus[below] = get_viewport().gui_get_focus_owner()
		_stack.append(root)
		_apply_mouse_mode()
		_focus_active.call_deferred(true)
	else:
		_close_menu(root)


func _close_menu(root: Node) -> void:
	var index := _stack.find(root)
	if index == -1:
		return
	var was_top := index == _stack.size() - 1
	_stack.remove_at(index)
	_saved_focus.erase(root)
	if was_top:
		_release_focus()
		_apply_mouse_mode()
		if device == Device.GAMEPAD:
			_cursor = get_viewport().get_mouse_position()
			_focus_active.call_deferred()


## The open menu on top, or null.
func _active() -> Node:
	while _stack.size() > 0 and not _is_open(_stack[-1]):
		_saved_focus.erase(_stack.pop_back())
	return _stack[-1] if _stack.size() > 0 else null


## Focuses the active menu: the control that was focused before something opened over it, otherwise its entry. [param fresh]
## ignores the remembered one, and waits a frame for the menu to finish building.
func _focus_active(fresh: bool = false) -> void:
	if fresh:
		await get_tree().process_frame
	if device != Device.GAMEPAD:
		return
	var root := _active()
	if root:
		_focus_entry(root, not fresh)


func _focus_entry(root: Node, use_saved: bool = true) -> Control:
	var control: Control = null
	var saved = _saved_focus.get(root)
	if use_saved and is_instance_valid(saved) and saved is Control and _can_focus(saved) and root.is_ancestor_of(saved):
		control = saved
	else:
		var entry: Callable = _menus[root].entry
		if entry.is_valid():
			var result = entry.call()
			if result is Control and _can_focus(result):
				control = result
		if control == null:
			var list := _focusables(root)
			if list.size() > 0:
				control = list[0]
	if control:
		control.grab_focus()
	return control


func _can_focus(control: Control) -> bool:
	if control.focus_mode != Control.FOCUS_ALL or control.is_queued_for_deletion() or not control.is_visible_in_tree():
		return false
	if control is BaseButton and control.disabled:
		return false
	if control is Slider and not control.editable:
		return false
	return true


## The controls of [param node]'s open subtree that can take focus, in tree order.
func _focusables(node: Node) -> Array[Control]:
	var list: Array[Control] = []
	_collect(node, list)
	return list


func _collect(node: Node, list: Array[Control]) -> void:
	if node.is_queued_for_deletion() or node is Window:
		return
	if (node is CanvasItem or node is CanvasLayer) and not node.visible:
		return
	if node is Control and _can_focus(node):
		list.append(node)
	for child in node.get_children():
		_collect(child, list)


func _step_focus(delta: float) -> void:
	var direction := _nav_direction()
	if direction == Vector2.ZERO:
		_held = Vector2.ZERO
		return
	if direction != _held:
		_held = direction
		_held_time = 0.0
		_navigate(direction)
		return
	_held_time += delta
	if _held_time >= NAV_DELAY:
		_held_time = NAV_DELAY - NAV_INTERVAL
		_navigate(direction)


## The d-pad, else the left stick, as one of the four directions (or none).
func _nav_direction() -> Vector2:
	var dpad := _dpad()
	if dpad != Vector2.ZERO:
		return Vector2(dpad.x, 0.0) if dpad.x != 0.0 else dpad
	var stick := Vector2(Input.get_joy_axis(_pad_id, JOY_AXIS_LEFT_X), Input.get_joy_axis(_pad_id, JOY_AXIS_LEFT_Y))
	if maxf(absf(stick.x), absf(stick.y)) < NAV_THRESHOLD:
		return Vector2.ZERO
	if absf(stick.x) >= absf(stick.y):
		return Vector2(signf(stick.x), 0.0)
	return Vector2(0.0, signf(stick.y))


## Moves the focus one step in [param direction] (a unit vector), looping past the ends. Sliders take left and right as value
## changes. True if the step was taken here, false if the built-in handling should have it.
func _navigate(direction: Vector2) -> bool:
	var root := _active()
	if root == null:
		return false
	var focus := get_viewport().gui_get_focus_owner()
	var list := _focusables(root)
	if focus == null or not list.has(focus):
		return _focus_entry(root) != null
	var navigate: Callable = _menus[root].navigate
	if navigate.is_valid() and navigate.call(direction):
		return true
	if focus is HSlider and direction.x != 0.0:
		_nudge(focus, direction.x)
		return true
	var target := _neighbour(focus, direction, list)
	if target == null:
		target = _wrapped(focus, direction, list)
	if target and target != focus:
		target.grab_focus()
	return true


## About 40 presses cover a slider's range.
func _nudge(slider: HSlider, sign_x: float) -> void:
	var step := slider.step if slider.step > 0.0 else (slider.max_value - slider.min_value) / 100.0
	var presses := maxi(1, int((slider.max_value - slider.min_value) / step / 40.0))
	slider.value += sign_x * step * presses


func _center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()


## The nearest control in [param direction], favouring ones straight ahead.
func _neighbour(from: Control, direction: Vector2, list: Array[Control]) -> Control:
	var origin := _center(from)
	var best: Control = null
	var best_score := INF
	for control in list:
		if control == from:
			continue
		var delta := _center(control) - origin
		var along := delta.dot(direction)
		if along <= 1.0:
			continue
		var score := along + absf(delta.cross(direction)) * 2.0
		if score < best_score:
			best_score = score
			best = control
	return best


## Past the last control: the far end, in line with [param from]. With nothing behind it (a single row asked to go up or down),
## the next or previous control in order.
func _wrapped(from: Control, direction: Vector2, list: Array[Control]) -> Control:
	var origin := _center(from)
	var furthest := -INF
	for control in list:
		if control != from:
			furthest = maxf(furthest, -(_center(control) - origin).dot(direction))
	if furthest > 1.0:
		var best: Control = null
		var best_across := INF
		for control in list:
			if control == from:
				continue
			var delta := _center(control) - origin
			if -delta.dot(direction) >= furthest - 24.0:
				var across := absf(delta.cross(direction))
				if across < best_across:
					best_across = across
					best = control
		return best
	var index := list.find(from)
	var step := 1 if direction.x > 0.0 or direction.y > 0.0 else -1
	return list[posmod(index + step, list.size())]


# ===========================================================================================================================================
# Glyphs
# ===========================================================================================================================================


## The icon for [param action] on the active device (key, mouse button or gamepad button), or null if there is none.
func glyph(action: StringName) -> Texture2D:
	var events: Array[InputEvent] = InputMap.action_get_events(action) if InputMap.has_action(action) else []
	if device == Device.GAMEPAD:
		var folder := "playstation" if pad == Pad.PLAYSTATION else "xbox"
		for event in events:
			if event is InputEventJoypadButton:
				return _texture("%s%s/button_%d.png" % [GLYPHS, folder, event.button_index])
		for event in events:
			if event is InputEventJoypadMotion:
				return _texture("%s%s/axis_%d_%s.png" % [GLYPHS, folder, event.axis, "minus" if event.axis_value < 0.0 else "plus"])
		if GAMEPAD_ALIASES.has(action):
			return glyph(GAMEPAD_ALIASES[action])
		return null
	for event in events:
		if event is InputEventKey:
			var code: Key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
			var texture := _texture("%skeyboard/%s.png" % [GLYPHS, OS.get_keycode_string(code)])
			if texture:
				return texture
	for event in events:
		if event is InputEventMouseButton:
			return _texture("%smouse/button_%d.png" % [GLYPHS, event.button_index])
	return null


func _texture(path: String) -> Texture2D:
	if not _textures.has(path):
		_textures[path] = load(path) if ResourceLoader.exists(path) else null
	return _textures[path]
