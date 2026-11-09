class_name DiceDesigner
extends CanvasLayer

## The dice designer, from the main menu: how every die will look. Along the top, a random die of each rarity in the
## current look; below, rows that scroll sideways: the designs (shapes; locked ones greyed out, hovering says how to
## unlock them), the main finish, and - for designs with a trim - the trim's finish. Clicking a card picks it and
## saves straight away. Every die is turnable as usual. CLOSE, Esc or right-click leaves.
## Use: designer.open()

signal closed

const PREVIEW_SIZE: float = 150.0
const CARD_VIEW_SIZE: float = 104.0
const CARD_WIDTH: float = 150.0
## The die shown on cards: plain, so the finish is what you see
const SAMPLE_DIE: StringName = &"all_rounder"
const GOLD: Color = Color(1.0, 0.82, 0.35)

var _root: Control
var _previews: HBoxContainer
var _designs: HBoxContainer
var _finishes: HBoxContainer
var _trims: HBoxContainer
var _trim_section: Control


func _ready() -> void:
	layer = 40
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_root = MarginContainer.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		_root.add_theme_constant_override("margin_" + side, 80)
	for side in ["top", "bottom"]:
		_root.add_theme_constant_override("margin_" + side, 36)
	add_child(_root)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_root.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := _label(tr("DESIGNER_TITLE"), 40, GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	if OS.is_debug_build():
		var unlock_all := Button.new()
		unlock_all.text = "DEBUG: UNLOCK ALL"
		unlock_all.custom_minimum_size = Vector2(240, 50)
		unlock_all.add_theme_font_size_override("font_size", 20)
		unlock_all.modulate = Color(1.0, 0.45, 0.85)
		unlock_all.pressed.connect(_unlock_all)
		header.add_child(unlock_all)
	var close := Button.new()
	close.text = tr("BTN_CLOSE")
	close.custom_minimum_size = Vector2(160, 50)
	close.add_theme_font_size_override("font_size", 22)
	close.pressed.connect(close_designer)
	header.add_child(close)

	_previews = HBoxContainer.new()
	_previews.alignment = BoxContainer.ALIGNMENT_CENTER
	_previews.add_theme_constant_override("separation", 30)
	column.add_child(_previews)
	_designs = _row(column, tr("DESIGNER_DESIGN"))
	_finishes = _row(column, tr("DESIGNER_FINISH"))
	_trims = _row(column, tr("DESIGNER_TRIM_FINISH"))
	_trim_section = _trims.get_parent().get_parent()
	InputMode.register_menu(self, _entry)
	ButtonPrompt.footer(self, ButtonPrompt.standard("PROMPT_PICK", "PROMPT_CLOSE"))


## The first design card.
func _entry() -> Control:
	var cards := _live(_designs)
	return cards[0] if cards.size() > 0 else null


func _live(row: Container) -> Array[Node]:
	var cards: Array[Node] = []
	for card in row.get_children():
		if not card.is_queued_for_deletion():
			cards.append(card)
	return cards


## Where the focus is, as [row, card] (rows: designs, finishes, trims), or empty.
func _focus_slot() -> Array[int]:
	var focus := get_viewport().gui_get_focus_owner()
	var rows: Array[Container] = [_designs, _finishes, _trims]
	for r in rows.size():
		var index := _live(rows[r]).find(focus)
		if index != -1:
			return [r, index]
	return []


## Cards are rebuilt on every pick: puts the focus back on the same slot.
func _restore_focus(slot: Array[int]) -> void:
	if slot.is_empty():
		return
	var rows: Array[Container] = [_designs, _finishes, _trims]
	var cards := _live(rows[slot[0]])
	if cards.is_empty():
		return
	var card: Control = cards[mini(slot[1], cards.size() - 1)]
	if card.is_visible_in_tree():
		card.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		close_designer()


func open() -> void:
	visible = true
	_rebuild()


func close_designer() -> void:
	visible = false
	for row in [_previews, _designs, _finishes, _trims]:
		for child in row.get_children():
			child.queue_free()
	closed.emit()


# ===========================================================================================================================================
# Rows
# ===========================================================================================================================================


func _rebuild() -> void:
	var slot := _focus_slot()
	var progression := SaveManager.progression_data
	var design := _current_design()
	for row in [_previews, _designs, _finishes, _trims]:
		for child in row.get_children():
			child.queue_free()

	# A random die of each rarity, in the current look
	for tier in Rarity.Tier.values():
		var options: Array = Database.get_all("dice").filter(func(t: DieType): return t.rarity == tier)
		options.append_array(Database.get_all("dice_debug").filter(func(t: DieType): return t.rarity == tier))
		if options.is_empty():
			continue
		var box := VBoxContainer.new()
		var view := DieView.create(options.pick_random(), PREVIEW_SIZE)
		view.design = design
		box.add_child(view)
		box.add_child(_label(Rarity.display_name(tier), 18, Rarity.COLORS[tier]))
		_previews.add_child(box)

	var designs: Array[DieDesign] = []
	designs.assign(Database.get_all("die_designs"))
	# Unlocked first, then by name
	designs.sort_custom(func(a: DieDesign, b: DieDesign):
		var ua := progression.is_design_unlocked(a)
		var ub := progression.is_design_unlocked(b)
		return ua and not ub if ua != ub else a.display_name < b.display_name)
	for each in designs:
		var unlocked := progression.is_design_unlocked(each)
		var tip := ""
		if not unlocked:
			var challenge := progression.challenge_for(each.id)
			tip = tr("DESIGNER_LOCKED_TIP") % [challenge.description, challenge.progress_text(progression)] if challenge else tr("DESIGNER_LOCKED")
		_designs.add_child(_card(each.display_name, each, null, null, each == design, unlocked, tip,
			func(): _pick("die_design", String(each.id))))

	var finishes: Array[DieFinish] = []
	finishes.assign(Database.get_all("die_finishes"))
	finishes.sort_custom(func(a: DieFinish, b: DieFinish): return a.display_name < b.display_name)
	var main := Die3D.player_finish(false)
	var trim := Die3D.player_finish(true)
	for each in finishes:
		_finishes.add_child(_card(each.display_name, design, each, trim, each == main, true, "",
			func(): _pick("die_finish", String(each.id))))
	_trim_section.visible = design.has_trim()
	if design.has_trim():
		for each in finishes:
			_trims.add_child(_card(each.display_name, design, main, each, each == trim, true, "",
				func(): _pick("die_trim_finish", String(each.id))))
	_restore_focus.call_deferred(slot)


## Sets the progression's [property] to [id], saves and redraws.
func _pick(property: String, id: String) -> void:
	SaveManager.progression_data.set(property, id)
	SaveManager.save_data()
	_rebuild()


## Debug: unlocks all characters, dice, items and designs, saves and redraws.
func _unlock_all() -> void:
	SaveManager.progression_data.unlock_all()
	SaveManager.save_data()
	_rebuild()


func _current_design() -> DieDesign:
	var design: DieDesign = Database.get_content("die_designs", SaveManager.progression_data.die_design)
	return design if design else Database.get_all("die_designs")[0]


## A titled row of cards that scrolls sideways. Returns the box the cards go in.
func _row(parent: Control, title: String) -> HBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	parent.add_child(section)
	section.add_child(_label(title, 20, Color(0.8, 0.8, 0.85), HORIZONTAL_ALIGNMENT_LEFT))
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size.y = CARD_VIEW_SIZE + 64.0
	section.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	scroll.add_child(row)
	return row


## A card: the sample die in [design] with the given finishes (null: the player's), its [title], highlighted when
## [selected]; greyed out with [tip] when not [unlocked]. Clicking an unlocked card calls [on_pick].
func _card(title: String, design: DieDesign, main: DieFinish, trim: DieFinish, selected: bool, unlocked: bool, tip: String,
		on_pick: Callable) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = CARD_WIDTH
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14)
	style.border_color = GOLD if selected else Color(0.3, 0.3, 0.36)
	style.set_border_width_all(3 if selected else 1)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(6)
	panel.add_theme_stylebox_override("panel", style)
	panel.tooltip_text = tip
	# Focusable for the gamepad: a white border
	panel.focus_mode = Control.FOCUS_ALL
	var rest_color := style.border_color
	var rest_width := 3 if selected else 1
	panel.focus_entered.connect(func():
		style.border_color = Color.WHITE
		style.set_border_width_all(3))
	panel.focus_exited.connect(func():
		style.border_color = rest_color
		style.set_border_width_all(rest_width))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(box)
	var view := DieView.create(Database.get_content("dice", SAMPLE_DIE), CARD_VIEW_SIZE, selected)
	view.design = design
	view.finish = main
	view.trim_finish = trim
	view.inspect_on_click = false
	view.tooltip_text = tip
	view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(view)
	box.add_child(_label(title if unlocked else tr("DESIGNER_LOCKED_TITLE") % title, 17, GOLD if selected else Color.WHITE))
	if unlocked:
		view.clicked.connect(on_pick)
		panel.gui_input.connect(func(event: InputEvent):
			if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept"):
				on_pick.call())
	else:
		panel.modulate = Color(0.45, 0.45, 0.5)
	return panel


func _label(text: String, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
