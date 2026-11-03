class_name EquipmentAward
extends CanvasLayer

## A new item, celebrated in the centre of the screen like a new die (DieAward): its icon pops in big over a glow in
## its rarity colour, with what it does. With a free slot of its kind it's equipped (EQUIP); with none, the items in
## those slots are shown to replace, or it can be left. Updates the run's equipment itself. Runs while the game is
## paused (chest items pause it mid-move).
## Use: await award.present(item, "Boss reward") - true if the item was equipped.

signal _finished

const GLOW: Texture2D = preload("res://assets/ui/disc.png")
const TITLE_COLOR: Color = Color(1.0, 0.82, 0.35)
const ICON_SIZE: float = 170.0
const SCREEN_MARGIN: float = 40.0

var _content: VBoxContainer
var _glow: TextureRect
var _item: EquipmentData
var _cards: Array[EquipmentCard] = []
var _slots: Array[int] = []
var _replace: int = -1
var _replace_button: Button
var _taken: bool = false


func _ready() -> void:
	layer = 52
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.9)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	center.add_child(_content)


func _process(delta: float) -> void:
	if visible and _glow:
		_glow.rotation += delta * 0.6
		_glow.scale = Vector2.ONE * (1.0 + 0.06 * sin(Time.get_ticks_msec() / 260.0))


## Shows [item] from [source], then equips it, replaces an item with it or leaves it, as the player chooses.
## Returns true unless it was left.
func present(item: EquipmentData, source: String) -> bool:
	_item = item
	_taken = false
	_cards.clear()
	_replace = -1
	for child in _content.get_children():
		child.queue_free()
	var run := SaveManager.run_data
	_slots = RunData.slots_for(item)
	var free_slot := -1
	for index in _slots:
		if run.item_in(index) == null:
			free_slot = index
			break

	var title := _label("NEW ITEM!", 56, TITLE_COLOR)
	_content.add_child(title)
	_content.add_child(_label(source, 20, Color(0.7, 0.7, 0.75)))
	var stage := Control.new()
	stage.custom_minimum_size = Vector2.ONE * ICON_SIZE * 1.4
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(stage)
	_glow = TextureRect.new()
	_glow.texture = GLOW
	_glow.modulate = Color(Rarity.COLORS[item.rarity], 0.55)
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.pivot_offset = stage.custom_minimum_size / 2.0
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_glow)
	var icon := EquipmentCard.icon(item, ICON_SIZE)
	icon.position = Vector2.ONE * ICON_SIZE * 0.2
	icon.size = Vector2.ONE * ICON_SIZE
	icon.pivot_offset = icon.size / 2.0
	stage.add_child(icon)

	_content.add_child(_label(item.display_name, 36, Rarity.COLORS[item.rarity].lightened(0.2)))
	_content.add_child(_label(item.kind(), 18, Color(0.65, 0.65, 0.7)))
	var rows := InfoPanel.content("", item.info_rows(), 560.0, 19)
	rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(rows)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	if free_slot != -1:
		buttons.add_child(_button("EQUIP", _equip.bind(free_slot)))
	else:
		_content.add_child(_label("Your %s slot%s full. Choose an item to replace, or leave it." % [
			EquipmentData.SLOT_NAMES[item.slot].to_lower(), "s are" if _slots.size() > 1 else " is"], 20, Color.WHITE))
		var current := HBoxContainer.new()
		current.alignment = BoxContainer.ALIGNMENT_CENTER
		current.add_theme_constant_override("separation", 14)
		_content.add_child(current)
		for i in _slots.size():
			var card := EquipmentCard.create(run.item_in(_slots[i]), 400.0, "REPLACE", 56.0)
			card.button_pressed.connect(_choose_replace.bind(i))
			current.add_child(card)
			_cards.append(card)
		_replace_button = _button("REPLACE", _do_replace)
		_replace_button.disabled = true
		buttons.add_child(_replace_button)
	buttons.add_child(_button("LEAVE IT", _finished.emit))
	_content.add_child(buttons)

	visible = true
	_content.scale = Vector2.ONE
	_content.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	var available := _content.get_viewport_rect().size.y - 2.0 * SCREEN_MARGIN
	_content.pivot_offset = _content.size / 2.0
	var fit := minf(1.0, available / _content.size.y)
	_content.scale = Vector2.ONE * fit * 0.8
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_content, "modulate:a", 1.0, Anim.t(0.2))
	tween.tween_property(_content, "scale", Vector2.ONE * fit, Anim.t(0.45)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	icon.scale = Vector2.ONE * 0.05
	icon.rotation = -0.6
	var pop := create_tween().set_parallel(true)
	pop.tween_property(icon, "scale", Vector2.ONE, Anim.t(0.6)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	pop.tween_property(icon, "rotation", 0.0, Anim.t(0.5)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	title.pivot_offset = title.size / 2.0
	title.scale = Vector2.ONE * 0.3
	create_tween().tween_property(title, "scale", Vector2.ONE, Anim.t(0.6)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	await _finished
	var out := create_tween().set_parallel(true)
	out.tween_property(_content, "modulate:a", 0.0, Anim.t(0.2))
	out.tween_property(_content, "scale", Vector2.ONE * fit * 0.85, Anim.t(0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await out.finished
	visible = false
	_glow = null
	for child in _content.get_children():
		child.queue_free()
	return _taken


func _equip(index: int) -> void:
	SaveManager.run_data.equip(_item, index)
	SaveManager.run_data.items_obtained += 1
	_taken = true
	_finished.emit()


func _choose_replace(card: int) -> void:
	_replace = -1 if _replace == card else card
	for i in _cards.size():
		_cards[i].selected = i == _replace
	_replace_button.disabled = _replace == -1
	_replace_button.text = "REPLACE  %s → %s" % [_cards[_replace].item.display_name, _item.display_name] if _replace != -1 else "REPLACE"


func _do_replace() -> void:
	var card := _cards[_replace]
	card.pivot_offset = card.size / 2.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ONE * 0.1, Anim.t(0.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "modulate:a", 0.0, Anim.t(0.25))
	await tween.finished
	_equip(_slots[_replace])


func _button(text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 54)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(action)
	return button


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
