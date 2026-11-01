class_name CharacterPicker
extends CanvasLayer

## Placeholder character choice at the start of a new run (the real select screen comes in Phase 10).
## Clicking a card selects it (scales up in place, PLAY highlighted); PLAY starts the run.
## Use: var id: StringName = await picker.pick()

signal picked(id: StringName)

## Display order
const ORDER: Array[StringName] = [&"knight", &"assassin", &"mage"]
const SELECTED_SCALE: float = 1.08
const HIGHLIGHT: Color = Color(1.0, 0.82, 0.35)

@onready var cards: HBoxContainer = %Cards

## Per character: [panel, play button, panel style]
var _cards: Dictionary[StringName, Array] = {}
var _selected: StringName = &""


func pick() -> StringName:
	for child in cards.get_children():
		child.queue_free()
	_cards.clear()
	_selected = &""
	for id in ORDER:
		var character: CharacterData = Database.get_content("characters", id)
		if character:
			cards.add_child(_card(character))
	visible = true
	var id: StringName = await picked
	visible = false
	return id


func _card(character: CharacterData) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(320, 380)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.14)
	style.border_color = character.tint
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", style)
	panel.gui_input.connect(_on_card_input.bind(character.id))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)

	var portrait := TextureRect.new()
	portrait.texture = character.texture
	portrait.modulate = character.tint
	portrait.custom_minimum_size = Vector2(0, 110)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(portrait)
	box.add_child(_label(character.display_name, 30, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label("HP %d  ·  Range %d" % [character.max_hp, character.attack_range], 18, HORIZONTAL_ALIGNMENT_CENTER))
	for ability in character.abilities:
		var text := _label("%s: %s" % [ability.display_name, ability.description], 17, HORIZONTAL_ALIGNMENT_LEFT)
		text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(text)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var button := Button.new()
	button.text = "PLAY"
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(picked.emit.bind(character.id))
	box.add_child(button)
	_cards[character.id] = [panel, button, style]
	return panel


func _on_card_input(event: InputEvent, id: StringName) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select(id)


## Scales the chosen card up in place and highlights its PLAY button; the others go back to normal.
func _select(id: StringName) -> void:
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


func _label(text: String, size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	return label
