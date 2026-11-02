class_name DicePoolView
extends CanvasLayer

## The run's dice pool: every die as a turnable card (click one for its six faces), and how full the pool is.
## Toggled from the top bar's die or the [code]dice_pool[/code] key; click outside, right-click, Esc or CLOSE closes.

const COLUMNS: int = 5
const VIEW_SIZE: float = 120.0

var max_size: int = 10
var _content: VBoxContainer


func _ready() -> void:
	layer = 37
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("select") or event.is_action_pressed("cancel"):
			close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 18)
	center.add_child(_content)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		close()


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	for child in _content.get_children():
		child.queue_free()
	var dice := SaveManager.run_data.dice
	var title := Label.new()
	title.text = "YOUR DICE  %d / %d" % [dice.size(), max_size]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	_content.add_child(title)
	var hint := Label.new()
	hint.text = "Drag a die to turn it  ·  click one to see all six faces"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	_content.add_child(hint)
	var grid := DieCard.grid(sorted_types(dice), COLUMNS, VIEW_SIZE)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(grid)
	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(200, 50)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.pressed.connect(close)
	_content.add_child(close_button)
	visible = true
	_content.modulate.a = 0.0
	create_tween().tween_property(_content, "modulate:a", 1.0, Anim.t(0.15))


func close() -> void:
	visible = false
	for child in _content.get_children():
		child.queue_free()


## The pool's die types, rarest first, then by name.
static func sorted_types(ids: Array[String]) -> Array[DieType]:
	var types: Array[DieType] = []
	for id in ids:
		types.append(Database.get_content("dice", id))
	types.sort_custom(func(a: DieType, b: DieType): return a.rarity > b.rarity or (a.rarity == b.rarity and a.display_name < b.display_name))
	return types
