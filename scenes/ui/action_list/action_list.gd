class_name ActionList
extends PanelContainer

## Side panel listing the planned actions (the turn planner). Click a set entry to rewind to it, edit it or delete it.
## Each entry has two lines: the action (dice value and target) and, under it in small pale grey, how it adds up and
## everything that changes it. The entry being made or edited is white; set entries take their action's colour
## (green for movement, red for attacks); entries already played out turn grey. The panel runs from just under the
## top bar to just above the dice row's buttons ([method _place]).

signal rewind_requested(index: int)
signal edit_requested(index: int)
signal delete_requested(index: int)
signal play_pressed
## LEAVE LEVEL, shown in place of PLAY TURN by [method show_leave]
signal leave_pressed

enum Option { REWIND, EDIT, DELETE }

## Entry statuses (see [method show_entries])
const ACTIVE: StringName = &"active"
const SET: StringName = &"set"
const PLAYED: StringName = &"played"
const LOG: StringName = &"log"

const PLAY_ICON: String = "res://assets/ui/icons/play_turn.png"
## Height of the top bar (scenes/ui/top_bar/top_bar.tscn) and the gap kept to it and to the dice row's buttons
const TOP_BAR_HEIGHT: float = 66.0
const GAP: float = 12.0
const TITLE_SIZE: int = 31
## The breakdown line is 60% of the action line
const DETAIL_SIZE: int = 19

const ACTIVE_COLOR: Color = Color.WHITE
const MOVE_COLOR: Color = Color(0.45, 0.9, 0.5)
const ATTACK_COLOR: Color = Color(1.0, 0.42, 0.38)
## Ability actions (heals, cures)
const OTHER_COLOR: Color = Color(0.55, 0.78, 1.0)
const PLAYED_COLOR: Color = Color(0.5, 0.5, 0.53)
## Enemy attacks after the plan
const LOG_COLOR: Color = Color(1.0, 0.65, 0.3)
const DETAIL_COLOR: Color = Color(0.72, 0.72, 0.76)
const DETAIL_PLAYED_COLOR: Color = Color(0.42, 0.42, 0.45)

## Height of the dice row as a fraction of the screen (DiceTray.row_screen_y); the panel ends above its buttons
var row_y: float = 0.91:
	set(value):
		row_y = value
		if is_node_ready():
			_place()

@onready var header: Label = %Header
@onready var hint: Label = %Hint
@onready var scroll: ScrollContainer = %Scroll
@onready var entries: VBoxContainer = %Entries
@onready var play_button: Button = %PlayButton
@onready var menu: PopupMenu = %EntryMenu

var _menu_index: int = -1
var _entries: Array[Dictionary] = []
var _interactive: bool = true
var _leave_button: Button
## Room above PLAY TURN for the attack preview (AttackPreview)
var _preview_space: Control
var _active_entry: Control


func _ready() -> void:
	play_button.text = tr("BTN_PLAY_TURN")
	if ResourceLoader.exists(PLAY_ICON):
		play_button.icon = load(PLAY_ICON)
	play_button.add_theme_constant_override("icon_max_width", 40)
	play_button.add_theme_constant_override("h_separation", 14)
	play_button.pressed.connect(play_pressed.emit)
	_leave_button = Button.new()
	_leave_button.text = tr("BTN_LEAVE_LEVEL")
	_leave_button.custom_minimum_size = play_button.custom_minimum_size
	_leave_button.add_theme_font_size_override("font_size", 32)
	_leave_button.visible = false
	_leave_button.pressed.connect(leave_pressed.emit)
	play_button.add_sibling(_leave_button)
	_preview_space = Control.new()
	_preview_space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_preview_space.visible = false
	play_button.add_sibling(_preview_space)
	play_button.get_parent().move_child(_preview_space, play_button.get_index())
	menu.add_item(tr("ACTION_REWIND"), Option.REWIND)
	menu.add_item(tr("ACTION_EDIT"), Option.EDIT)
	menu.add_item(tr("ACTION_DELETE"), Option.DELETE)
	menu.id_pressed.connect(_on_menu_id_pressed)
	get_viewport().size_changed.connect(_place)
	_place()


## Rebuilds the entries. Each is a Dictionary: title (the action line), detail (the breakdown line, "" for none),
## kind (DieFace.Category: MOVE / ATTACK / OTHER, its colour once set) and status: ACTIVE (being made or edited:
## white), SET (its colour; clickable while [interactive]), PLAYED (grey) or LOG (an enemy attack after the plan).
func show_entries(list: Array[Dictionary], interactive: bool = true) -> void:
	if list == _entries and interactive == _interactive:
		return
	var previous := _entries.size()
	_entries = list.duplicate(true)
	_interactive = interactive
	_active_entry = null
	for child in entries.get_children():
		child.queue_free()
	var number := 0
	for i in list.size():
		var data := list[i]
		var status: StringName = data.get("status", SET)
		if status != LOG:
			number += 1
		var entry := _make_entry(data, number, status, interactive and status == SET, i)
		entries.add_child(entry)
		if status == ACTIVE:
			_active_entry = entry
		# New entries pop in
		if i >= previous:
			entry.pivot_offset_ratio = Vector2(0.5, 0.5)
			entry.scale = Vector2(0.6, 0.6)
			create_tween().tween_property(entry, "scale", Vector2.ONE, Anim.t(0.3)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if _active_entry:
		_scroll_to.call_deferred(_active_entry)


func _make_entry(data: Dictionary, number: int, status: StringName, clickable: bool, index: int) -> PanelContainer:
	var entry := PanelContainer.new()
	var normal := StyleBoxFlat.new()
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	normal.content_margin_top = 6.0
	normal.content_margin_bottom = 6.0
	normal.bg_color = Color(1, 1, 1, 0.09) if status == ACTIVE else Color(1, 1, 1, 0.0)
	if status == ACTIVE:
		normal.border_color = Color(1, 1, 1, 0.35)
		normal.border_width_left = 3
	entry.add_theme_stylebox_override("panel", normal)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(box)

	var colour := _title_colour(status, data.get("kind", DieFace.Category.OTHER))
	var title := _label(data.get("title", ""), TITLE_SIZE, colour)
	title.text = ("»  " if status == LOG else "%d.  " % number) + title.text
	box.add_child(title)
	var detail: String = data.get("detail", "")
	if detail != "":
		box.add_child(_label(detail, DETAIL_SIZE, DETAIL_PLAYED_COLOR if status == PLAYED else DETAIL_COLOR))

	if clickable:
		entry.mouse_filter = Control.MOUSE_FILTER_STOP
		entry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var hover := normal.duplicate() as StyleBoxFlat
		hover.bg_color = Color(1, 1, 1, 0.06)
		entry.mouse_entered.connect(func(): entry.add_theme_stylebox_override("panel", hover))
		entry.mouse_exited.connect(func(): entry.add_theme_stylebox_override("panel", normal))
		entry.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				entry.accept_event()
				_open_menu(index, entry))
	else:
		entry.mouse_filter = Control.MOUSE_FILTER_PASS
	return entry


func _title_colour(status: StringName, kind: int) -> Color:
	match status:
		ACTIVE:
			return ACTIVE_COLOR
		PLAYED:
			return PLAYED_COLOR
		LOG:
			return LOG_COLOR
	match kind:
		DieFace.Category.MOVE:
			return MOVE_COLOR
		DieFace.Category.ATTACK:
			return ATTACK_COLOR
	return OTHER_COLOR


func _label(text: String, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	# Wrap rather than widen the panel
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 1
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _scroll_to(entry: Control) -> void:
	if is_instance_valid(entry) and entry.is_inside_tree():
		scroll.ensure_control_visible(entry)


## Docks the panel on the left or right edge of the screen.
func set_side(left: bool) -> void:
	var width := offset_right - offset_left
	anchor_left = 0.0 if left else 1.0
	anchor_right = anchor_left
	# Grow away from the screen edge if the content ever needs more room
	grow_horizontal = Control.GROW_DIRECTION_END if left else Control.GROW_DIRECTION_BEGIN
	offset_left = 20.0 if left else -20.0 - width
	offset_right = offset_left + width


## From just under the top bar to just above the round buttons beside the dice row ("enemies go first", abilities).
func _place() -> void:
	var screen := get_viewport_rect().size
	offset_top = TOP_BAR_HEIGHT + GAP
	var buttons_top := screen.y * row_y - CircleButton.DIAMETER / 2.0
	offset_bottom = buttons_top - GAP - screen.y


func set_header(text: String) -> void:
	header.text = text


func set_hint(text: String) -> void:
	hint.text = text


## Screen rect of entry [index] (or just under the last entry), e.g. for things flying into the plan.
func entry_rect(index: int) -> Rect2:
	var children := entries.get_children().filter(func(c: Node): return not c.is_queued_for_deletion())
	if index < children.size():
		return children[index].get_global_rect()
	var bottom := entries.get_global_rect()
	return Rect2(bottom.position + Vector2(0, bottom.size.y), Vector2(bottom.size.x, 40))


## Makes room of [height] above PLAY TURN for the attack preview (0 to take it away).
func reserve_preview(height: float) -> void:
	_preview_space.visible = height > 0.0
	_preview_space.custom_minimum_size.y = height


## Screen rect kept for the attack preview (see [method reserve_preview]).
func preview_rect() -> Rect2:
	var rect := scroll.get_global_rect()
	return Rect2(Vector2(rect.position.x, _preview_space.get_global_rect().position.y), Vector2(rect.size.x, _preview_space.size.y))


## Swaps PLAY TURN for LEAVE LEVEL (a cleared level with a shop or bank, left when the player is done with them).
func show_leave(shown: bool) -> void:
	_leave_button.visible = shown
	play_button.visible = not shown


func set_play_enabled(enabled: bool) -> void:
	play_button.disabled = not enabled


func _open_menu(index: int, entry: Control) -> void:
	_menu_index = index
	menu.position = Vector2i(entry.get_screen_position() + Vector2(0, entry.size.y))
	menu.popup()


func _on_menu_id_pressed(id: int) -> void:
	match id:
		Option.REWIND:
			rewind_requested.emit(_menu_index)
		Option.EDIT:
			edit_requested.emit(_menu_index)
		Option.DELETE:
			delete_requested.emit(_menu_index)
