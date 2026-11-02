class_name CharacterPicker
extends CanvasLayer

## Character select at the start of a new run. One card per character (by [member CharacterData.order]): its
## cut-out on a tile, health and range, passive and active, and the six faces of its unique starting die (every
## character also starts with normal dice, explained under the title). Up to [constant COLUMNS] cards a row,
## extra rows below, all centred and the same size (scaled down together if the rows don't fit the screen).
## Locked characters are greyed out and can't be picked.
## Clicking a card selects it (scales up in place, the cut-out hops, PLAY highlighted); PLAY starts the run.
## Use: var id: StringName = await picker.pick() - empty if the player backed out.

signal picked(id: StringName)

const COLUMNS: int = 4
const CARD_WIDTH: float = 340.0
const PORTRAIT_HEIGHT: float = 190.0
## Space kept above and below the cards when they're scaled down to fit
const SCREEN_MARGIN: float = 40.0
const SELECTED_SCALE: float = 1.06
const HIGHLIGHT: Color = Color(1.0, 0.82, 0.35)
const HEART: Texture2D = preload("res://assets/ui/icons/heart.png")
const BOW: Texture2D = preload("res://assets/ui/icons/bow.png")
## The die every character starts with several of; any other starting die is the character's own
const NORMAL_DIE: StringName = &"normal"
const FACE_SIZE: float = 44.0

@onready var rows: VBoxContainer = %Rows
@onready var content: Control = %Content
@onready var back_button: Button = %BackButton

## Per character: [panel, play button, panel style, cut-out]
var _cards: Dictionary[StringName, Array] = {}
var _selected: StringName = &""


func _ready() -> void:
	back_button.pressed.connect(func(): picked.emit(&""))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		picked.emit(&"")


func pick() -> StringName:
	for child in rows.get_children():
		child.queue_free()
	_cards.clear()
	_selected = &""
	var characters: Array[CharacterData] = []
	characters.assign(Database.get_all("characters"))
	characters.sort_custom(func(a: CharacterData, b: CharacterData): return a.order < b.order)
	var row: HBoxContainer
	for i in characters.size():
		if i % COLUMNS == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 24)
			rows.add_child(row)
		row.add_child(_card(characters[i]))

	# Measured once laid out, so every card can take the tallest one's height
	content.modulate.a = 0.0
	content.scale = Vector2.ONE
	visible = true
	await get_tree().process_frame
	await get_tree().process_frame
	_even_out()
	await get_tree().process_frame
	_fit_to_screen()
	create_tween().tween_property(content, "modulate:a", 1.0, Anim.t(0.25))

	var id: StringName = await picked
	visible = false
	return id


func _even_out() -> void:
	var height := 0.0
	for id in _cards:
		height = maxf(height, _cards[id][0].get_combined_minimum_size().y)
	for id in _cards:
		_cards[id][0].custom_minimum_size.y = height


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
			if die and die_id != NORMAL_DIE:
				box.add_child(_die_faces(die))
	else:
		box.add_child(_wrapped("Locked.", 17))
		panel.modulate = Color(0.6, 0.6, 0.65)

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
	if unlocked:
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


## [die]'s name over its six faces, each explained on hover.
func _die_faces(die: DieType) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	var heading := _label(die.display_name, 19, HORIZONTAL_ALIGNMENT_LEFT)
	heading.add_theme_color_override("font_color", HIGHLIGHT)
	box.add_child(heading)
	var faces := HBoxContainer.new()
	faces.add_theme_constant_override("separation", 7)
	box.add_child(faces)
	for face in die.faces:
		var tile := PanelContainer.new()
		var style := StyleBoxFlat.new()
		# Dark face with a rarity border: symbol inks read better on dark than on the rarity colour
		style.bg_color = Color(0.17, 0.17, 0.21)
		style.border_color = Rarity.COLORS[die.rarity]
		style.set_border_width_all(2)
		style.set_corner_radius_all(7)
		style.set_content_margin_all(3)
		tile.add_theme_stylebox_override("panel", style)
		var icon := InfoIcon.new()
		icon.texture = DieFaceTextures.get_textures(face)[0]
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.custom_minimum_size = Vector2.ONE * (FACE_SIZE - 6.0)
		icon.set_info(die.display_name, HelpText.face_rows(face))
		tile.add_child(icon)
		faces.add_child(tile)
	return box


func _on_card_input(event: InputEvent, id: StringName) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select(id)


## Scales the chosen card up in place, hops its cut-out and highlights its PLAY button; the others go back to normal.
func _select(id: StringName) -> void:
	if id == _selected:
		return
	_selected = id
	for card_id in _cards:
		var panel: PanelContainer = _cards[card_id][0]
		var button: Button = _cards[card_id][1]
		var style: StyleBoxFlat = _cards[card_id][2]
		var chosen := card_id == id
		panel.pivot_offset = panel.size / 2.0
		create_tween().tween_property(panel, "scale", Vector2.ONE * (SELECTED_SCALE if chosen else 1.0), Anim.t(0.2)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
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
