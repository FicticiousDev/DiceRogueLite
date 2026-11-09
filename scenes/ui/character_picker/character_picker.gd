class_name CharacterPicker
extends CanvasLayer

## Character select at the start of a new run. One card per character (by [member CharacterData.order]): its
## cut-out on a tile, health and range, passive and active, and its unique starting die - turnable, click it for the
## inspector - with its six faces (every character also starts with the shared dice, explained under the title).
## The cards sit in a carousel: [constant SHOWN] at full size in the middle, and the ones beyond cascading away to each
## side, smaller, darker and tucked behind. The arrows either side, the left / right keys and the mouse wheel scroll it
## one card at a time; clicking a card in the cascade scrolls to it. All cards are the same size (the whole selection
## is scaled down if it doesn't fit the screen). Locked characters are greyed out and can't be picked; their card
## says how to unlock them (UnlockChallenge). Clicking a card selects it (scales up, the cut-out hops, PLAY
## highlighted); PLAY starts the run.
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

@onready var strip: Control = %Strip
@onready var content: Control = %Content
@onready var back_button: Button = %BackButton
@onready var left_arrow: Button = %LeftArrow
@onready var right_arrow: Button = %RightArrow

## Per character: [panel, play button, panel style, cut-out]
var _cards: Dictionary[StringName, Array] = {}
## Character ids in carousel order
var _order: Array[StringName] = []
var _selected: StringName = &""
## Index of the first of the full-size cards
var _first: int = 0
var _tween: Tween


func _ready() -> void:
	back_button.pressed.connect(func(): picked.emit(&""))
	left_arrow.pressed.connect(scroll.bind(-1))
	right_arrow.pressed.connect(scroll.bind(1))
	InputMode.register_menu(self, _entry, Callable(), _navigate)
	ButtonPrompt.footer(self, [[[&"ui_left", &"ui_right"], "Browse"], [[&"ui_accept"], "Play"], [[&"cancel"], "Back"]])


func _input(event: InputEvent) -> void:
	if not visible:
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
		if get_viewport().gui_get_focus_owner() != null:
			_card_focus().grab_focus()


## True unless the mouse is over something drawn above the picker (the die inspector, say).
func _hovering_picker() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	return hovered == null or is_ancestor_of(hovered)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		picked.emit(&"")


## The card in the middle of the full-size ones.
func _middle_id() -> StringName:
	return _order[clampi(_first + int(mini(SHOWN, _order.size()) / 2.0), 0, _order.size() - 1)]


## What the gamepad focuses: the PLAY button of the middle card (selecting the card), or BACK if it is locked.
func _card_focus() -> Control:
	if _order.is_empty():
		return back_button
	var id := _middle_id()
	var button: Button = _cards[id][1]
	if button.disabled:
		return back_button
	_select(id)
	return button


func _entry() -> Control:
	return _card_focus()


## Gamepad navigation: left and right turn the carousel, up and down switch between the card and BACK.
func _navigate(direction: Vector2) -> bool:
	if direction.x != 0.0:
		scroll(int(direction.x))
		_card_focus().grab_focus()
	elif get_viewport().gui_get_focus_owner() == back_button:
		_card_focus().grab_focus()
	else:
		back_button.grab_focus()
	return true


func pick() -> StringName:
	for child in strip.get_children():
		child.queue_free()
	_cards.clear()
	_order.clear()
	_selected = &""
	_first = 0
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
	_layout(false)
	await get_tree().process_frame
	_fit_to_screen()
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


## Scrolls the carousel by [step] cards (negative: left), keeping the full-size cards within the list.
func scroll(step: int) -> void:
	scroll_to(_first + step)


## Makes [first] the first full-size card (clamped).
func scroll_to(first: int) -> void:
	first = clampi(first, 0, maxi(_order.size() - SHOWN, 0))
	if first == _first:
		return
	_first = first
	_layout(true)


## Where each card sits for the current scroll: full-size ones side by side in the middle, the rest cascading out to
## each side, smaller, darker and further back (drawn behind, and below in input order). [animate] tweens there.
func _layout(animate: bool) -> void:
	if _tween:
		_tween.kill()
	if animate:
		_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	var shown := mini(SHOWN, _order.size())
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
		var depth := _depth(i)
		var side := -1.0 if i < _first else 1.0
		var x: float
		var card_scale := 1.0
		var shade := 1.0
		if depth == 0:
			x = centre + (i - _first - (shown - 1) / 2.0) * (CARD_WIDTH + CARD_GAP)
		else:
			card_scale = CASCADE_SCALES[mini(depth, CASCADE_SCALES.size()) - 1]
			shade = CASCADE_SHADES[mini(depth, CASCADE_SHADES.size()) - 1]
			var edge := (shown * CARD_WIDTH + (shown - 1) * CARD_GAP) / 2.0
			# The visible strip of each cascaded card runs out from under the one in front
			x = centre + side * (edge + _cascade_offset(depth) - CARD_WIDTH * card_scale / 2.0)
		if id == _selected:
			card_scale *= SELECTED_SCALE
		var hidden := depth > CASCADE_SCALES.size()
		var target_position := Vector2(x - CARD_WIDTH / 2.0, (strip.custom_minimum_size.y - panel.size.y) / 2.0)
		var tint: Color = _base_tint(id) * Color(shade, shade, shade, 0.0 if hidden else 1.0)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE if hidden else Control.MOUSE_FILTER_STOP
		if animate:
			_tween.tween_property(panel, "position", target_position, Anim.t(0.3))
			_tween.tween_property(panel, "scale", Vector2.ONE * card_scale, Anim.t(0.3))
			_tween.tween_property(panel, "modulate", tint, Anim.t(0.3))
		else:
			panel.position = target_position
			panel.scale = Vector2.ONE * card_scale
			panel.modulate = tint
	left_arrow.disabled = _first <= 0
	right_arrow.disabled = _first >= _order.size() - shown


## How far past the full-size cards the outer edge of the cascade's [depth]th card reaches: each shows
## [constant CASCADE_REVEAL] of itself beyond the one in front.
func _cascade_offset(depth: int) -> float:
	var offset := 0.0
	for k in mini(depth, CASCADE_SCALES.size()):
		offset += CARD_WIDTH * CASCADE_SCALES[k] * CASCADE_REVEAL
	return offset


## Places from the full-size cards: 0 for one of them, 1 for the next card out, and so on.
func _depth(index: int) -> int:
	if index < _first:
		return _first - index
	return maxi(index - (_first + mini(SHOWN, _order.size()) - 1), 0)


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
	box.add_child(_label(character.display_name, 30, HORIZONTAL_ALIGNMENT_CENTER))

	box.add_child(_gap(4))
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 24)
	var hp := StatIcon.create(HEART, Color(1, 0.35, 0.35), 20, 26.0)
	hp.label.text = "%d HP" % character.max_hp
	stats.add_child(hp)
	var range_stat := StatIcon.create(BOW, Color(0.95, 0.85, 0.6), 20, 26.0)
	range_stat.label.text = "Range %d" % character.attack_range if character.attack_range > 1 else "Melee"
	stats.add_child(range_stat)
	box.add_child(stats)
	box.add_child(_gap(4))

	if unlocked:
		# Descriptions already say whether an ability is passive or once per level
		for ability in character.abilities:
			var heading := _label(ability.display_name, 19, HORIZONTAL_ALIGNMENT_LEFT)
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
		var heading := _label("LOCKED", 19, HORIZONTAL_ALIGNMENT_LEFT)
		heading.add_theme_color_override("font_color", HIGHLIGHT)
		box.add_child(heading)
		if challenge:
			box.add_child(_wrapped("To unlock: %s" % challenge.description, 17))
			box.add_child(_wrapped("Progress: %s" % challenge.progress_text(SaveManager.progression_data), 17))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var button := Button.new()
	button.text = "PLAY" if unlocked else "LOCKED"
	button.disabled = not unlocked
	button.custom_minimum_size = Vector2(0, 50)
	button.add_theme_font_size_override("font_size", 22)
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
	var heading := _label(die.display_name, 19, HORIZONTAL_ALIGNMENT_LEFT)
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


## A click on a card in the cascade scrolls to it; on a full-size one, selects it (if unlocked).
func _on_card_input(event: InputEvent, id: StringName) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var index := _order.find(id)
	if index < _first:
		scroll_to(index)
	elif index >= _first + SHOWN:
		scroll_to(index - SHOWN + 1)
	elif SaveManager.progression_data.is_character_unlocked(Database.get_content("characters", id)):
		_select(id)


## Scales the chosen card up, hops its cut-out and highlights its PLAY button; the others go back to normal.
func _select(id: StringName) -> void:
	if id == _selected:
		return
	_selected = id
	_layout(true)
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
