class_name DiceDesigner
extends CanvasLayer

## The dice designer, from the main menu: how every die will look. Along the top, a random die of each rarity in the
## current look; below, rows that scroll sideways: the designs (shapes; locked ones greyed out, hovering says how to
## unlock them), the main finish, and the trim's finish (greyed out for designs without a trim). Designs and finishes
## are listed in ProgressionData.DIE_DESIGN_ORDER / DIE_FINISH_ORDER. Clicking a card picks it and saves straight away;
## the cards stay put and only their dice change. Every die is turnable as usual. The Close prompt, Esc or right-click
## leaves.
## Use: designer.open()

signal closed

const PREVIEW_SIZE: float = 150.0
const CARD_VIEW_SIZE: float = 104.0
const CARD_WIDTH: float = 150.0
## The die shown on cards: plain, so the finish is what you see
const SAMPLE_DIE: StringName = &"all_rounder"
const GOLD: Color = Color(1.0, 0.82, 0.35)
const GREYED: Color = Color(0.45, 0.45, 0.5)

## Which progression property a row sets
enum Row { DESIGN, FINISH, TRIM }

## A card in one of the rows, kept for the designer's lifetime so the rows never rebuild.
class Card:
	var row: Row
	## DieDesign or DieFinish
	var content: Resource
	var panel: PanelContainer
	var style: StyleBoxFlat
	var view: DieView
	var label: Label
	var selected: bool = false
	var enabled: bool = true

var _root: Control
var _previews: HBoxContainer
var _designs: HBoxContainer
var _finishes: HBoxContainer
var _trims: HBoxContainer
var _trim_section: Control
var _cards: Array[Card] = []
var _preview_views: Array[DieView] = []


func _ready() -> void:
	UITheme.watch(self)
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
	column.add_child(_label(tr("DESIGNER_TITLE"), 56, GOLD))

	_previews = HBoxContainer.new()
	_previews.alignment = BoxContainer.ALIGNMENT_CENTER
	_previews.add_theme_constant_override("separation", 30)
	column.add_child(_previews)
	_designs = _row(column, tr("DESIGNER_DESIGN"))
	_finishes = _row(column, tr("DESIGNER_FINISH"))
	_trims = _row(column, tr("DESIGNER_TRIM_FINISH"))
	_trim_section = _trims.get_parent().get_parent()
	InputMode.register_menu(self, _entry)
	var prompts := ButtonPrompt.standard("PROMPT_PICK", "")
	prompts.append([[&"cancel"], "PROMPT_CLOSE", close_designer])
	ButtonPrompt.footer(self, prompts)
	DebugConsole.progression_changed.connect(_on_progression_changed)


## The first design card.
func _entry() -> Control:
	for card in _cards:
		if card.row == Row.DESIGN:
			return card.panel
	return null


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		close_designer()


func open() -> void:
	visible = true
	_build()


func close_designer() -> void:
	visible = false
	for row in [_previews, _designs, _finishes, _trims]:
		for child in row.get_children():
			child.queue_free()
	_cards.clear()
	_preview_views.clear()
	closed.emit()


# ===========================================================================================================================================
# Rows
# ===========================================================================================================================================


## Creates the previews and cards, sets their look, then adds them (so each die is only built once).
func _build() -> void:
	# A random die of each rarity
	var preview_boxes: Array[Control] = []
	for tier in Rarity.Tier.values():
		var options: Array = Database.get_all("dice").filter(func(t: DieType): return t.rarity == tier)
		options.append_array(Database.get_all("dice_debug").filter(func(t: DieType): return t.rarity == tier))
		if options.is_empty():
			continue
		var box := VBoxContainer.new()
		var view := DieView.create(options.pick_random(), PREVIEW_SIZE)
		box.add_child(view)
		box.add_child(_label(Rarity.display_name(tier), 25, Rarity.COLORS[tier]))
		preview_boxes.append(box)
		_preview_views.append(view)

	for each in ProgressionData.sorted_by_order(Database.get_all("die_designs"), ProgressionData.DIE_DESIGN_ORDER):
		_add_card(Row.DESIGN, each)
	var finishes := ProgressionData.sorted_by_order(Database.get_all("die_finishes"), ProgressionData.DIE_FINISH_ORDER)
	for each in finishes:
		_add_card(Row.FINISH, each)
	for each in finishes:
		_add_card(Row.TRIM, each)
	_refresh()

	for box in preview_boxes:
		_previews.add_child(box)
	var rows: Array[HBoxContainer] = [_designs, _finishes, _trims]
	for card in _cards:
		rows[card.row].add_child(card.panel)
	# Again for the views' mouse filters, which DieView sets on entering the tree (the looks are unchanged, so cheap)
	_refresh()


## Updates every card and preview to the current look and unlocks, without rebuilding them.
func _refresh() -> void:
	var progression := SaveManager.progression_data
	var design := _current_design()
	var main := Die3D.player_finish(false)
	var trim := Die3D.player_finish(true)
	var has_trim := design.has_trim()
	_trim_section.modulate = Color.WHITE if has_trim else GREYED

	for view in _preview_views:
		view.set_look(design, main, trim)
	for card in _cards:
		var title: String = card.content.display_name
		# Tooltip rows, only for cards that can't be picked
		var tip: Array[Dictionary] = []
		match card.row:
			Row.DESIGN:
				card.selected = card.content == design
				card.enabled = progression.is_design_unlocked(card.content)
				if not card.enabled:
					var challenge := progression.challenge_for(card.content.id)
					if challenge:
						tip.append(InfoPanel.row(null, Color.WHITE, tr("CHARACTER_TO_UNLOCK") % challenge.description))
						tip.append(InfoPanel.row(null, Color.WHITE, tr("CHARACTER_PROGRESS") % challenge.progress_text(progression)))
					else:
						tip.append(InfoPanel.row(null, Color.WHITE, tr("DESIGNER_LOCKED")))
					title = tr("DESIGNER_LOCKED_TITLE") % title
				card.view.set_look(card.content, main, trim)
			Row.FINISH:
				card.selected = card.content == main
				card.view.set_look(design, card.content, trim)
			Row.TRIM:
				card.selected = card.content == trim
				card.enabled = has_trim
				if not has_trim:
					tip.append(InfoPanel.row(null, Color.WHITE, tr("TIP_DESIGNER_NO_TRIM")))
				card.view.set_look(design, main, card.content)
		card.label.text = title
		card.label.add_theme_color_override("font_color", GOLD if card.selected else Color.WHITE)
		var tip_title := title if not tip.is_empty() else ""
		Tooltip.set_info(card.panel, tip_title, tip)
		Tooltip.set_info(card.view, tip_title, tip)
		card.view.idle_spin = card.selected
		# Locked designs can still take focus, to read how to unlock them; the trim row can't while greyed out
		card.panel.focus_mode = Control.FOCUS_NONE if card.row == Row.TRIM and not card.enabled else Control.FOCUS_ALL
		# Locked designs stay turnable; greyed-out trims don't react at all
		card.view.mouse_filter = Control.MOUSE_FILTER_IGNORE if card.row == Row.TRIM and not card.enabled else Control.MOUSE_FILTER_STOP
		# The trim row is greyed out as a whole
		card.panel.modulate = GREYED if not card.enabled and card.row != Row.TRIM else Color.WHITE
		_style_card(card, card.panel.has_focus())


## Sets the progression's property for [card]'s row to its content, saves and redraws.
func _pick(card: Card) -> void:
	if not card.enabled:
		return
	var property: String = ["die_design", "die_finish", "die_trim_finish"][card.row]
	SaveManager.progression_data.set(property, String(card.content.id))
	SaveManager.save_data()
	_refresh()


## Debug console unlocks: redraws if open.
func _on_progression_changed() -> void:
	if visible:
		_refresh()


func _current_design() -> DieDesign:
	var design: DieDesign = Database.get_content("die_designs", SaveManager.progression_data.die_design)
	return design if design else Database.get_all("die_designs")[0]


## A titled row of cards that scrolls sideways. Returns the box the cards go in.
func _row(parent: Control, title: String) -> HBoxContainer:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	parent.add_child(section)
	section.add_child(_label(title, 28, Color(0.8, 0.8, 0.85), HORIZONTAL_ALIGNMENT_LEFT))
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	scroll.custom_minimum_size.y = CARD_VIEW_SIZE + 64.0
	section.add_child(scroll)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	scroll.add_child(row)
	return row


## Creates a card for [content]: the sample die, its name below. Its look and state are set by [method _refresh]; the
## caller adds it to its row.
func _add_card(row: Row, content: Resource) -> void:
	var card := Card.new()
	card.row = row
	card.content = content
	card.panel = PanelContainer.new()
	card.panel.custom_minimum_size.x = CARD_WIDTH
	card.style = StyleBoxFlat.new()
	card.style.bg_color = Color(0.1, 0.1, 0.14)
	card.style.set_corner_radius_all(10)
	card.style.set_content_margin_all(6)
	card.panel.add_theme_stylebox_override("panel", card.style)
	# Focusable for the gamepad: a white border
	card.panel.focus_mode = Control.FOCUS_ALL
	card.panel.focus_entered.connect(_style_card.bind(card, true))
	card.panel.focus_exited.connect(_style_card.bind(card, false))
	card.panel.gui_input.connect(func(event: InputEvent):
		if (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) or event.is_action_pressed("ui_accept"):
			_pick(card))
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.panel.add_child(box)
	card.view = DieView.create(Database.get_content("dice", SAMPLE_DIE), CARD_VIEW_SIZE, false)
	card.view.inspect_on_click = false
	card.view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	card.view.clicked.connect(_pick.bind(card))
	box.add_child(card.view)
	card.label = _label("", 24, Color.WHITE)
	box.add_child(card.label)
	_cards.append(card)


## Border: white while [focused], gold when selected, grey otherwise.
func _style_card(card: Card, focused: bool) -> void:
	if focused:
		card.style.border_color = Color.WHITE
	else:
		card.style.border_color = GOLD if card.selected else Color(0.3, 0.3, 0.36)
	card.style.set_border_width_all(3 if focused or card.selected else 1)


func _label(text: String, size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
