class_name DieCard
extends PanelContainer

## A die on a small card: a turnable [DieView] (click it for all six faces), its name in its rarity colour and an
## optional button. [member selected] thickens the border in the highlight colour.

signal button_pressed

const HIGHLIGHT: Color = Color(1.0, 0.82, 0.35)

var die_type: DieType
var view: DieView
var button: Button
var selected: bool = false:
	set(value):
		selected = value
		_style.border_color = HIGHLIGHT if value else Rarity.COLORS[die_type.rarity]
		_style.set_border_width_all(4 if value else 2)

var _style: StyleBoxFlat


## A card for [type]. [button_text] adds a button under the name.
static func create(type: DieType, view_size: float = 110.0, button_text: String = "") -> DieCard:
	var card := DieCard.new()
	card.die_type = type
	card._style = StyleBoxFlat.new()
	card._style.bg_color = Color(0.1, 0.1, 0.14)
	card._style.border_color = Rarity.COLORS[type.rarity]
	card._style.set_border_width_all(2)
	card._style.set_corner_radius_all(10)
	card._style.set_content_margin_all(8)
	card.add_theme_stylebox_override("panel", card._style)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	card.view = DieView.create(type, view_size)
	card.view.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(card.view)
	var name_label := Label.new()
	name_label.text = type.display_name
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 17)
	name_label.add_theme_color_override("font_color", Rarity.COLORS[type.rarity].lightened(0.2))
	name_label.custom_minimum_size.x = view_size
	box.add_child(name_label)
	if button_text != "":
		card.button = Button.new()
		card.button.text = button_text
		card.button.custom_minimum_size = Vector2(0, 38)
		card.button.add_theme_font_size_override("font_size", 16)
		card.button.pressed.connect(card.button_pressed.emit)
		box.add_child(card.button)
	return card


## A grid of cards for [types], [columns] wide. Cards are returned in the grid's children, in order.
static func grid(types: Array[DieType], columns: int, view_size: float = 110.0, button_text: String = "") -> GridContainer:
	var result := GridContainer.new()
	result.columns = columns
	result.add_theme_constant_override("h_separation", 12)
	result.add_theme_constant_override("v_separation", 12)
	for type in types:
		result.add_child(create(type, view_size, button_text))
	return result
