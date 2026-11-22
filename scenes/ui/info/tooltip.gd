class_name Tooltip
extends RefCounted

## The one tooltip style and its on/off switch (Settings > General > Show Tooltips). Every tooltip is an [InfoPanel]:
## a gold title and optional rows of icon + text, in the theme's TooltipPanel frame, sized to its text up to
## [constant WIDTH].
## Controls get one with [method set_info]; their [code]_make_custom_tooltip[/code] returns [method make]. A control
## without a script is given [constant HOST], so any Control can take one. Tooltips placed by hand (dice in the tray,
## exit gates) use [method panel], [method delay] and [method enabled].

const HOST: Script = preload("res://scenes/ui/info/tooltip_host.gd")
const GROUP: StringName = &"tooltips"
const WIDTH: float = 380.0
const FONT_SIZE: int = 24
const _TITLE: StringName = &"tooltip_title"
const _ROWS: StringName = &"tooltip_rows"


static func enabled() -> bool:
	return SaveManager.settings_data.show_tooltips


## Seconds the mouse rests before a tooltip opens (the engine's, so hand-placed tooltips match the built-in ones).
static func delay() -> float:
	return ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5)


## Gives [param control] a tooltip of [param title] and rows from [method InfoPanel.row]; an empty title and no rows
## removes it. Call again to change it.
static func set_info(control: Control, title: String, rows: Array[Dictionary] = []) -> void:
	if control.get_script() == null:
		control.set_script(HOST)
	control.set_meta(_TITLE, title)
	control.set_meta(_ROWS, rows)
	if control.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		control.mouse_filter = Control.MOUSE_FILTER_PASS
	if not control.is_in_group(GROUP):
		control.add_to_group(GROUP)
	_apply(control)


## The tooltip content for [param control], for its [code]_make_custom_tooltip[/code].
static func make(control: Control) -> Control:
	var rows: Array[Dictionary] = []
	rows.assign(control.get_meta(_ROWS, []))
	return InfoPanel.content(control.get_meta(_TITLE, ""), rows, WIDTH, FONT_SIZE, true)


## A framed tooltip to place by hand.
static func panel(title: String, rows: Array[Dictionary] = []) -> InfoPanel:
	return InfoPanel.create(title, rows, WIDTH, FONT_SIZE, true)


## Re-applies the setting to every tooltip in [param tree] (after it changes).
static func refresh(tree: SceneTree) -> void:
	for node in tree.get_nodes_in_group(GROUP):
		_apply(node)


## Built-in tooltips only open when there's some text, so it stands in for the content (and is cleared to switch it off).
static func _apply(control: Control) -> void:
	var text: String = control.get_meta(_TITLE, "")
	if text == "" and not (control.get_meta(_ROWS, []) as Array).is_empty():
		text = " "
	control.tooltip_text = text if enabled() else ""
