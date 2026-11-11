class_name CharacterPicker
extends CanvasLayer

## Character select at the start of a new run. One card per character (by [member CharacterData.order]): its
## cut-out on a tile, health and range, passive and active, and its unique starting die - turnable, click it for the
## inspector - with its six faces (every character also starts with the shared dice, explained under the title).
## The cards sit in a carousel that wraps around: [constant SHOWN] at full size in the middle, and the ones beyond cascading
## away to each side, smaller, darker and tucked behind. The arrows either side (the left / right prompts of the active
## device), the left / right keys and the mouse wheel turn it one card at a time, selecting the middle card; clicking a
## card in the cascade turns it to the middle. Hovering a full-size card selects it (scales up, the cut-out hops, PLAY
## highlighted); PLAY, the accept action or the PLAY prompt starts the run with it. All cards are the same size (the whole selection is scaled down if it doesn't fit
## the screen). Locked characters are greyed out and can't be picked; their card says how to unlock them (UnlockChallenge).
## Use: var id: StringName = await picker.pick() - empty if the player backed out.

signal picked(id: StringName)

## Cards shown at full size
const SHOWN: int = 3
## Scale, then brightness, of a card 1, 2, 3... places beyond the full-size ones; further ones are hidden
const CASCADE_SCALES: Array[float] = [0.72, 0.52]
const CASCADE_SHADES: Array[float] = [0.6, 0.4]
## Share of a cascaded card that shows past the card in front of it
const CASCADE_REVEAL: float = 0.5
const CARD_GAP: float = 24.0
const CARD_WIDTH: float = 340.0
const PORTRAIT_HEIGHT: float = 190.0
## Space kept above and below the cards when they're scaled down to fit
const SCREEN_MARGIN: float = 40.0
const SELECTED_SCALE: float = 1.06
const HIGHLIGHT: Color = Color(1.0, 0.82, 0.35)
const HEART: Texture2D = preload("res://assets/ui/icons/heart.png")
const BOW: Texture2D = preload("res://assets/ui/icons/bow.png")
## The dice every character starts with; any other starting die is the character's own
const SHARED_DICE: Array[StringName] = [&"movement", &"defence", &"attack"]
const FACE_SIZE: float = 44.0
const DIE_VIEW_SIZE: float = 100.0
## Distance of the PLAY / BACK prompts from the bottom-right corner
const PROMPT_MARGIN: float = 28.0

@onready var strip: Control = %Strip
@onready var content: Control = %Content
@onready var left_arrow: TextureButton = %LeftArrow
@onready var right_arrow: TextureButton = %RightArrow

## Per character: [panel, play button, panel style, cut-out]
var _cards: Dictionary[StringName, Array] = {}
## Character ids in carousel order
var _order: Array[StringName] = []
var _selected: StringName = &""
## Index of the middle card
var _centre: int = 0
## Per character: places from the middle at the last layout (negative: left), to spot cards wrapping round
var _offsets: Dictionary[StringName, int] = {}
## Places the carousel turned since the last layout (negative: left)
var _turn: int = 0
var _tween: Tween


func _ready() -> void:
	left_arrow.pressed.connect(scroll.bind(-1))
	right_arrow.pressed.connect(scroll.bind(1))
	InputMode.register_menu(self, _entry, Callable(), _navigate)
	InputMode.device_changed.connect(_refresh_arrows)
	_refresh_arrows()
	_add_prompts()


## PLAY above BACK in the bottom-right corner, clickable.
func _add_prompts() -> void:
	var box := ButtonPrompt.bar([
		[[&"ui_accept"], "PROMPT_PLAY", _play_selected],
		[[&"cancel"], "PROMPT_BACK", picked.emit.bind(&"")],
	], true)
	# Anchors first: setting one moves the offsets to keep the control where it was
	box.anchor_left = 1.0
	box.anchor_right = 1.0
	box.anchor_top = 1.0
	box.anchor_bottom = 1.0
	box.offset_left = -PROMPT_MARGIN
	box.offset_right = -PROMPT_MARGIN
	box.offset_top = -PROMPT_MARGIN
	box.offset_bottom = -PROMPT_MARGIN
	box.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(box)


## The arrows show the left / right prompts of the active device.
func _refresh_arrows() -> void:
	left_arrow.texture_normal = InputMode.glyph(&"ui_left")
	right_arrow.texture_normal = InputMode.glyph(&"ui_right")


## Bumps [arrow] as the carousel turns its way.
func _pulse(arrow: Control) -> void:
	arrow.pivot_offset = arrow.size / 2.0
	var tween := create_tween()
	tween.tween_property(arrow, "scale", Vector2.ONE * 1.25, Anim.t(0.06))
	tween.tween_property(arrow, "scale", Vector2.ONE, Anim.t(0.15)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseMotion:
		_hover(event)
		return
	var step := 0
	# Keys only: a gamepad steps through _navigate
	if event is InputEventKey and event.is_action_pressed("ui_left", true):
		step = -1
	elif event is InputEventKey and event.is_action_pressed("ui_right", true):
		step = 1
	elif event is InputEventMouseButton and event.pressed and _hovering_picker():
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_LEFT:
				step = -1
			MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_RIGHT:
				step = 1
	if step != 0:
		get_viewport().set_input_as_handled()
		scroll(step)
		if get_viewport().gui_get_focus_owner() != null and _card_focus():
			_card_focus().grab_focus()


## True unless the mouse is over something drawn above the picker (the die inspector, say).
func _hovering_picker() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered == null or is_ancestor_of(hovered)


## Selects the full-size card under the mouse. Checked by rect rather than mouse_entered, so the card's own buttons and
## die views don't get in the way; full-size cards don't overlap, and are drawn over the cascades.
func _hover(event: InputEventMouseMotion) -> void:
	if InputMode.is_gamepad() or not _hovering_picker():
		return
	for id in _cards:
		if _depth(_order.find(id)) == 0 and _cards[id][0].get_global_rect().has_point(event.position):
			_select(id)
			return


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		picked.emit(&"")
	elif event.is_action_pressed("ui_accept"):
		# Not while something drawn over the picker has the focus
		var focus := get_viewport().gui_get_focus_owner()
		if focus == null or is_ancestor_of(focus):
			get_viewport().set_input_as_handled()
			_play_selected()


## Starts the run with the selected character, if it's unlocked.
func _play_selected() -> void:
	if _selected == &"":
		return
	if SaveManager.progression_data.is_character_unlocked(Database.get_content("characters", _selected)):
		picked.emit(_selected)


## The card in the middle of the full-size ones.
func _middle_id() -> StringName:
	return _order[_centre]


## What the gamepad focuses: the middle card (selecting it). The accept action plays it from there (see _unhandled_input).
func _card_focus() -> Control:
	if _order.is_empty():
		return null
	var id := _middle_id()
	_select(id)
	return _cards[id][0]


func _entry() -> Control:
	return _card_focus()


## Gamepad navigation: left and right turn the carousel; up and down do nothing.
func _navigate(direction: Vector2) -> bool:
	if direction.x != 0.0:
		scroll(int(direction.x))
		var focus := _card_focus()
		if focus:
			focus.grab_focus()
	return true


func pick() -> StringName:
	for child in strip.get_children():
		child.queue_free()
	_cards.clear()
	_order.clear()
	_offsets.clear()
	_selected = &""
	_centre = 0
	var characters: Array[CharacterData] = []
	characters.assign(Database.get_all("characters"))
	characters.sort_custom(func(a: CharacterData, b: CharacterData): return a.order < b.order)
	for character in characters:
		strip.add_child(_card(character))
		_order.append(character.id)

	# Measured once laid out, so every card can take the tallest one's height
	content.modulate.a = 0.0
	content.scale = Vector2.ONE
	visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	_even_out()
	await get_tree().process_frame
	left_arrow.visible = _order.size() > 1
	right_arrow.visible = _order.size() > 1
	_layout(false)
	await get_tree().process_frame
	_fit_to_screen()
	if not _order.is_empty():
		_select(_middle_id())
	create_tween().tween_property(content, "modulate:a", 1.0, Anim.t(0.25))

	var id: StringName = await picked
	visible = false
	return id


## Gives every card the tallest one's height and sizes the strip to hold the full-size cards and the cascades.
func _even_out() -> void:
	var height := 0.0
	for id in _cards:
		height = maxf(height, _cards[id][0].get_combined_minimum_size().y)
	for id in _cards:
		var panel: Control = _cards[id][0]
		panel.custom_minimum_size.y = height
		panel.size = Vector2(CARD_WIDTH, height)
		panel.pivot_offset = panel.size / 2.0
	var shown := mini(SHOWN, _order.size())
	var width := shown * CARD_WIDTH + (shown - 1) * CARD_GAP
	if _order.size() > shown:
		width += 2.0 * _cascade_offset(CASCADE_SCALES.size())
	# Room for the selected card to grow
	strip.custom_minimum_size = Vector2(width, height) * Vector2(1.0, SELECTED_SCALE) + Vector2(CARD_WIDTH * (SELECTED_SCALE - 1.0), 0.0)


# ===========================================================================================================================================
# Carousel
# ===========================================================================================================================================


## Turns the carousel by [step] cards (negative: left), wrapping round, and selects the new middle card.
func scroll(step: int) -> void:
	if _order.size() < 2 or step == 0:
		return
	_pulse(left_arrow if step < 0 else right_arrow)
	scroll_to(_centre + step)


## Turns the carousel so card [index] (wrapped) is in the middle, and selects it.
func scroll_to(index: int) -> void:
	index = posmod(index, _order.size())
	if index == _centre:
		return
	_turn = _offset(index)
	_centre = index
	_set_selected(_middle_id())
	_layout(true)


## Places card [index] is from the middle card, going the shorter way round (negative: left).
func _offset(index: int) -> int:
	var low := -int(_order.size() / 2.0)
	return posmod(index - _centre - low, _order.size()) + low


## The range of offsets that are full size: [first, last].
func _full_size_range() -> Vector2i:
	var shown := mini(SHOWN, _order.size())
	var first := -int(shown / 2.0)
	return Vector2i(first, first + shown - 1)


## Where each card sits for the current turn: full-size ones side by side in the middle, the rest cascading out to
## each side, smaller, darker and further back (drawn behind, and below in input order). [animate] tweens there; a card
## wrapping round to the other side jumps there and fades in rather than sliding across.
func _layout(animate: bool) -> void:
	if _tween:
		_tween.kill()
	if animate:
		_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	var shown := mini(SHOWN, _order.size())
	var full := _full_size_range()
	var centre := strip.custom_minimum_size.x / 2.0
	# Nearest the middle drawn last, so it's on top and gets the clicks
	var by_depth: Array[int] = []
	for i in _order.size():
		by_depth.append(i)
	by_depth.sort_custom(func(a: int, b: int): return _depth(a) > _depth(b))
	for i in by_depth:
		var id := _order[i]
		var panel: Control = _cards[id][0]
		strip.move_child(panel, -1)
		var offset := _offset(i)
		var depth := _depth(i)
		var side := -1.0 if offset < 0 else 1.0
		var x: float
		var card_scale := 1.0
		var shade := 1.0
		if depth == 0:
			x = centre + (offset - (full.x + full.y) / 2.0) * (CARD_WIDTH + CARD_GAP)
		else:
			card_scale = CASCADE_SCALES[mini(depth, CASCADE_SCALES.size()) - 1]
			shade = CASCADE_SHADES[mini(depth, CASCADE_SHADES.size()) - 1]
			var edge := (shown * CARD_WIDTH + (shown - 1) * CARD_GAP) / 2.0
			# The visible strip of each cascaded card runs out from under the one in front
			x = centre + side * (edge + _cascade_offset(depth) - CARD_WIDTH * card_scale / 2.0)
		if id == _selected and depth == 0:
			card_scale *= SELECTED_SCALE
		var hidden := depth > CASCADE_SCALES.size()
		var target_position := Vector2(x - CARD_WIDTH / 2.0, (strip.custom_minimum_size.y - panel.size.y) / 2.0)
		var tint: Color = _base_tint(id) * Color(shade, shade, shade, 0.0 if hidden else 1.0)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE if hidden else Control.MOUSE_FILTER_STOP
		# Every card moves the other way by the turn, except those that went round the back
		var wrapped := _offsets.has(id) and offset != _offsets[id] - _turn
		_offsets[id] = offset
		if animate and wrapped:
			panel.position = target_position
			panel.scale = Vector2.ONE * card_scale
			panel.modulate = Color(tint, 0.0)
			_tween.tween_property(panel, "modulate", tint, Anim.t(0.3))
		elif animate:
			_tween.tween_property(panel, "position", target_position, Anim.t(0.3))
			_tween.tween_property(panel, "scale", Vector2.ONE * card_scale, Anim.t(0.3))
			_tween.tween_property(panel, "modulate", tint, Anim.t(0.3))
		else:
			panel.position = target_position
			panel.scale = Vector2.ONE * card_scale
			panel.modulate = tint
	_turn = 0


## How far past the full-size cards the outer edge of the cascade's [depth]th card reaches: each shows
## [constant CASCADE_REVEAL] of itself beyond the one in front.
func _cascade_offset(depth: int) -> float:
	var offset := 0.0
	for k in mini(depth, CASCADE_SCALES.size()):
		offset += CARD_WIDTH * CASCADE_SCALES[k] * CASCADE_REVEAL
	return offset


## Places from the full-size cards: 0 for one of them, 1 for the next card out, and so on.
func _depth(index: int) -> int:
	var offset := _offset(index)
	var full := _full_size_range()
	if offset < full.x:
		return full.x - offset
	return maxi(offset - full.y, 0)


## A card's colour before any cascade shading: greyed out if locked.
func _base_tint(id: StringName) -> Color:
	var character: CharacterData = Database.get_content("characters", id)
	return Color.WHITE if SaveManager.progression_data.is_character_unlocked(character) else Color(0.6, 0.6, 0.65)


## Scales the whole selection down about its centre if it's taller than the screen.
func _fit_to_screen() -> void:
	var available := content.get_viewport_rect().size.y - 2.0 * SCREEN_MARGIN
	content.pivot_offset = content.size / 2.0
	content.scale = Vector2.ONE * minf(1.0, available / content.size.y)


# ===========================================================================================================================================
# Cards
# ===========================================================================================================================================


func _card(character: CharacterData) -> Control:
	var unlocked := SaveManager.progression_data.is_character_unlocked(character)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	# Takes the gamepad focus (see _card_focus)
	panel.focus_mode = Control.FOCUS_ALL
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14)
	style.border_color = character.tint if unlocked else Color(0.35, 0.35, 0.4)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	var portrait := _portrait(character, unlocked)
	box.add_child(portrait[0])
	box.add_child(_label(character.display_name, 42, HORIZONTAL_ALIGNMENT_CENTER))

	box.add_child(_gap(4))
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 24)
	var hp := StatIcon.create(HEART, Color(1, 0.35, 0.35), 28, 26.0)
	hp.label.text = "%d HP" % character.max_hp
	stats.add_child(hp)
	var range_stat := StatIcon.create(BOW, Color(0.95, 0.85, 0.6), 28, 26.0)
	range_stat.label.text = tr("CHARACTER_RANGE") % character.attack_range if character.attack_range > 1 else tr("CHARACTER_MELEE")
	stats.add_child(range_stat)
	box.add_child(stats)
	box.add_child(_gap(4))

	if unlocked:
		# Descriptions already say whether an ability is passive or once per level
		for ability in character.abilities:
			var heading := _label(ability.display_name, 27, HORIZONTAL_ALIGNMENT_LEFT)
			heading.add_theme_color_override("font_color", HIGHLIGHT)
			box.add_child(heading)
			box.add_child(_wrapped(ability.description, 17))
			box.add_child(_gap(2))
		for die_id in character.starting_dice:
			var die: DieType = Database.get_content("dice", die_id)
			if die and die_id not in SHARED_DICE:
				box.add_child(_die_faces(die))
	else:
		# How to unlock it, with progress so far
		var challenge := SaveManager.progression_data.challenge_for(character.id)
		var heading := _label(tr("CHARACTER_LOCKED_HEADING"), 27, HORIZONTAL_ALIGNMENT_LEFT)
		heading.add_theme_color_override("font_color", HIGHLIGHT)
		box.add_child(heading)
		if challenge:
			box.add_child(_wrapped(tr("CHARACTER_TO_UNLOCK") % challenge.description, 17))
			box.add_child(_wrapped(tr("CHARACTER_PROGRESS") % challenge.progress_text(SaveManager.progression_data), 17))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var button := Button.new()
	button.text = tr("BTN_PLAY") if unlocked else tr("CHARACTER_LOCKED_HEADING")
	button.disabled = not unlocked
	button.custom_minimum_size = Vector2(0, 50)
	button.add_theme_font_size_override("font_size", 31)
	button.pressed.connect(picked.emit.bind(character.id))
	box.add_child(button)
	panel.gui_input.connect(_on_card_input.bind(character.id))
	_cards[character.id] = [panel, button, style, portrait[1]]
	return panel


## The character's cut-out standing on a tile, in its own small 3D world. Returns [container, cut-out].
func _portrait(character: CharacterData, unlocked: bool) -> Array:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(0, PORTRAIT_HEIGHT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(viewport)

	var camera := Camera3D.new()
	camera.fov = 32.0
	viewport.add_child(camera)
	camera.look_at_from_position(Vector3(0, 1.1, 3.3), Vector3(0, 0.42, 0))
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 30, 0)
	light.shadow_enabled = true
	viewport.add_child(light)

	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.75
	mesh.bottom_radius = 0.75
	mesh.height = 0.2
	mesh.radial_segments = 6
	mesh.rings = 1
	var material := StandardMaterial3D.new()
	material.albedo_color = character.tint.darkened(0.55) if unlocked else Color(0.15, 0.15, 0.18)
	mesh.material = material
	var tile := MeshInstance3D.new()
	tile.mesh = mesh
	tile.position.y = -0.1
	viewport.add_child(tile)

	var cutout := Cutout.new()
	cutout.texture = character.texture
	# Locked characters are a dark silhouette
	cutout.tint = character.tint if unlocked else Color(0.05, 0.05, 0.07)
	cutout.height = 0.85
	viewport.add_child(cutout)
	return [container, cutout]


## [die]'s name over the die itself (drag to turn it, click for the inspector) and its six faces, each explained on hover.
func _die_faces(die: DieType) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var heading := _label(die.display_name, 27, HORIZONTAL_ALIGNMENT_LEFT)
	heading.add_theme_color_override("font_color", HIGHLIGHT)
	box.add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	box.add_child(row)
	row.add_child(DieView.create(die, DIE_VIEW_SIZE))
	var faces := GridContainer.new()
	faces.columns = 3
	faces.add_theme_constant_override("h_separation", 7)
	faces.add_theme_constant_override("v_separation", 7)
	faces.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(faces)
	for face in die.faces:
		faces.add_child(DieInspector.face_tile(face, die.rarity, FACE_SIZE, die.display_name))
	return box


## A click on a card in the cascade turns it to the middle; on a full-size one, selects it.
func _on_card_input(event: InputEvent, id: StringName) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var index := _order.find(id)
	if _depth(index) > 0:
		scroll_to(index)
	else:
		_select(id)


## Selects full-size card [id] and lays the carousel out for it.
func _select(id: StringName) -> void:
	if id == _selected:
		return
	_set_selected(id)
	_layout(true)


## Scales the chosen card up (in the next layout), hops its cut-out and highlights its PLAY button (unless it's locked);
## the others go back to normal.
func _set_selected(id: StringName) -> void:
	if id == _selected:
		return
	_selected = id
	for card_id in _cards:
		var panel: PanelContainer = _cards[card_id][0]
		var button: Button = _cards[card_id][1]
		var style: StyleBoxFlat = _cards[card_id][2]
		var chosen := card_id == id
		style.set_border_width_all(4 if chosen else 2)
		# Brought to the front so the scaled card isn't covered by its neighbours
		panel.z_index = 1 if chosen else 0
		if chosen:
			_hop(_cards[card_id][3])
			var highlight := StyleBoxFlat.new()
			highlight.bg_color = HIGHLIGHT
			highlight.set_corner_radius_all(8)
			button.add_theme_stylebox_override("normal", highlight)
			button.add_theme_stylebox_override("hover", highlight)
			button.add_theme_color_override("font_color", Color(0.1, 0.08, 0.05))
			button.add_theme_color_override("font_hover_color", Color(0.1, 0.08, 0.05))
		else:
			button.remove_theme_stylebox_override("normal")
			button.remove_theme_stylebox_override("hover")
			button.remove_theme_color_override("font_color")
			button.remove_theme_color_override("font_hover_color")


## Jumps and spins the cut-out once, squashing on take-off and landing.
func _hop(cutout: Cutout) -> void:
	var body := cutout.body
	body.rotation.y = 0.0
	create_tween().tween_property(body, "rotation:y", TAU, Anim.t(0.5)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var tween := create_tween()
	tween.tween_property(body, "scale", Vector3(1.15, 0.8, 1.0), Anim.t(0.06))
	tween.tween_property(body, "scale", Vector3(0.9, 1.15, 1.0), Anim.t(0.1))
	tween.parallel().tween_property(body, "position:y", 0.45, Anim.t(0.22)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(body, "scale", Vector3.ONE, Anim.t(0.12))
	tween.parallel().tween_property(body, "position:y", 0.0, Anim.t(0.22)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	tween.tween_property(body, "scale", Vector3(1.2, 0.8, 1.0), Anim.t(0.06))
	tween.tween_property(body, "scale", Vector3.ONE, Anim.t(0.3)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _label(text: String, size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	return label


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	return gap


func _wrapped(text: String, size: int) -> Label:
	var label := _label(text, size, HORIZONTAL_ALIGNMENT_LEFT)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = CARD_WIDTH - 36.0
	return label
