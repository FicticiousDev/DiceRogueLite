class_name EquipmentCard
extends PanelContainer

## An item on a card: its icon in its rarity colour, name, kind ("Rare armour") and what its abilities do, with an
## optional button. [member selected] highlights the border.

signal button_pressed

const HIGHLIGHT: Color = Color(1.0, 0.82, 0.35)

var item: EquipmentData
var button: Button
var selected: bool = false:
	set(value):
		selected = value
		_style.border_color = HIGHLIGHT if value else Rarity.COLORS[item.rarity]
		_style.set_border_width_all(4 if value else 2)

var _style: StyleBoxFlat


static func create(equipment: EquipmentData, width: float = 420.0, button_text: String = "", icon_size: float = 72.0) -> EquipmentCard:
	var card := EquipmentCard.new()
	card.item = equipment
	card._style = StyleBoxFlat.new()
	card._style.bg_color = Color(0.1, 0.1, 0.14)
	card._style.border_color = Rarity.COLORS[equipment.rarity]
	card._style.set_border_width_all(2)
	card._style.set_corner_radius_all(10)
	card._style.set_content_margin_all(10)
	card.add_theme_stylebox_override("panel", card._style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	card.add_child(row)
	row.add_child(icon(equipment, icon_size))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	var name_label := Label.new()
	name_label.text = equipment.display_name
	name_label.add_theme_font_size_override("font_size", 28)
	name_label.add_theme_color_override("font_color", Rarity.COLORS[equipment.rarity].lightened(0.2))
	info.add_child(name_label)
	var kind := Label.new()
	kind.text = equipment.kind()
	kind.add_theme_font_size_override("font_size", 21)
	kind.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	info.add_child(kind)
	info.add_child(InfoPanel.content("", equipment.info_rows(), width - icon_size - 70.0, 21))
	if button_text != "":
		card.button = Button.new()
		card.button.text = button_text
		card.button.custom_minimum_size = Vector2(0, 38)
		card.button.add_theme_font_size_override("font_size", 22)
		card.button.pressed.connect(card.button_pressed.emit)
		info.add_child(card.button)
	return card


## The item's icon in its rarity colour.
static func icon(equipment: EquipmentData, icon_size: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = equipment.get_icon()
	rect.modulate = Rarity.COLORS[equipment.rarity]
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2.ONE * icon_size
	rect.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect
