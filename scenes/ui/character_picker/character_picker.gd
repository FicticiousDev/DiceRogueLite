class_name CharacterPicker
extends CanvasLayer

## Placeholder character choice at the start of a new run (the real select screen comes in Phase 10).
## Use: var id: StringName = await picker.pick()

signal picked(id: StringName)

## Display order
const ORDER: Array[StringName] = [&"knight", &"assassin", &"mage"]

@onready var cards: HBoxContainer = %Cards


func pick() -> StringName:
	for child in cards.get_children():
		child.queue_free()
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
	return panel


func _label(text: String, size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", size)
	return label
