extends CanvasLayer
class_name SettingsScene

## Autoloaded settings menu. Saved settings are applied on startup by SettingsOptions.
## Call Settings.show_settings() from any scene.
## Full-screen menu. The options are split into tabs (General, Graphics, Audio) shown in a centred tab bar, with the prompts for
## stepping through them (Q / E, LB / RB) on either side. The Done button shows the icon of the cancel action.

## Tab page names, in tab order, mapped to their localisation keys
const TAB_KEYS: Array[String] = ["SETTINGS_TAB_GENERAL", "SETTINGS_TAB_GRAPHICS", "SETTINGS_TAB_AUDIO"]

@onready var menu: ColorRect = $Menu
@onready var mouse_blocker: ColorRect = $MouseBlocker
@onready var tabs: TabContainer = %Tabs
@onready var tab_bar: TabBar = %TabBar
@onready var prompt_left: Control = %PromptLeft
@onready var prompt_right: Control = %PromptRight
@onready var done_button: Button = %DoneButton

const ACTION_PREV: StringName = &"settings_tab_prev"
const ACTION_NEXT: StringName = &"settings_tab_next"

var _tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputMode.register_menu(menu)
	_register_tab_actions()
	for i in TAB_KEYS.size():
		tab_bar.add_tab()
	_update_tab_titles()
	prompt_left.add_child(ButtonPrompt.create([ACTION_PREV], ""))
	prompt_right.add_child(ButtonPrompt.create([ACTION_NEXT], ""))
	tab_bar.tab_changed.connect(_on_tab_changed)
	InputMode.device_changed.connect(_refresh_done_icon)
	_refresh_done_icon()


func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSLATION_CHANGED and is_node_ready():
		_update_tab_titles()


func show_settings() -> void:
	# Always opens on the first tab (while hidden, so no focus is grabbed)
	tab_bar.current_tab = 0
	tabs.current_tab = 0
	_reset_scroll()

	menu.visible = true
	mouse_blocker.visible = true

	if _tween:
		_tween.kill()
	menu.modulate.a = 0.0
	_tween = create_tween()
	_tween.tween_property(menu, "modulate:a", 1.0, Anim.t(0.25)).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)


func hide_settings() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(menu, "modulate:a", 0.0, Anim.t(0.2)).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)

	# Wait for the tween to finish before hiding
	await _tween.finished
	menu.visible = false
	mouse_blocker.visible = false


func is_open() -> bool:
	return menu.visible


# ===========================================================================================================================================
# Tabs
# ===========================================================================================================================================


func _update_tab_titles() -> void:
	for i in TAB_KEYS.size():
		tab_bar.set_tab_title(i, tr(TAB_KEYS[i]))


## Adds the tab-stepping actions at runtime: Q / E on the keyboard, LB / RB on a gamepad.
func _register_tab_actions() -> void:
	var bindings := {ACTION_PREV: [KEY_Q, JOY_BUTTON_LEFT_SHOULDER], ACTION_NEXT: [KEY_E, JOY_BUTTON_RIGHT_SHOULDER]}
	for action: StringName in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = bindings[action][0]
		InputMap.action_add_event(action, key)
		var button := InputEventJoypadButton.new()
		button.button_index = bindings[action][1]
		InputMap.action_add_event(action, button)


## Steps [param direction] (-1 or 1) tabs, wrapping at the ends.
func _step_tab(direction: int) -> void:
	tab_bar.current_tab = posmod(tab_bar.current_tab + direction, tab_bar.tab_count)


func _on_tab_changed(index: int) -> void:
	tabs.current_tab = index
	_reset_scroll()
	# The focus was on the tab that just hid: move it to the new tab's first control
	if is_open() and InputMode.is_gamepad():
		var first := _first_focusable(tabs.get_current_tab_control())
		if first:
			first.grab_focus()


func _reset_scroll() -> void:
	var page := tabs.get_current_tab_control()
	var scroll := page as ScrollContainer if page is ScrollContainer else page.get_node_or_null("Scroll") as ScrollContainer
	if scroll:
		scroll.scroll_vertical = 0


## The first control under [param node] that takes focus, in tree order.
func _first_focusable(node: Node) -> Control:
	for child in node.get_children():
		if not child is Control or not child.visible:
			continue
		var can_focus: bool = child.focus_mode == Control.FOCUS_ALL
		if child is BaseButton and child.disabled:
			can_focus = false
		if child is Slider and not child.editable:
			can_focus = false
		if can_focus:
			return child
		var found := _first_focusable(child)
		if found:
			return found
	return null


# ===========================================================================================================================================
# Done button
# ===========================================================================================================================================


## The Done button's icon is the glyph of the cancel action on the active device
func _refresh_done_icon() -> void:
	done_button.icon = InputMode.glyph(&"cancel")


func _on_done_button_pressed():
	SaveManager.save_data()
	hide_settings()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open():
		return
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_on_done_button_pressed()
	elif event.is_action_pressed(ACTION_PREV):
		get_viewport().set_input_as_handled()
		_step_tab(-1)
	elif event.is_action_pressed(ACTION_NEXT):
		get_viewport().set_input_as_handled()
		_step_tab(1)
