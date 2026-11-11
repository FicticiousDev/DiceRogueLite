class_name ShopMenu
extends CanvasLayer

## Opened by clicking the shop: its offers side by side, each die or item on its card (dice turn and open the
## inspector as anywhere else) with a BUY button showing the price - greyed out when the player can't afford it,
## SOLD once bought. The run does the buying (through DieAward / EquipmentAward) and opens the menu again after.
## Use: var index := await menu.choose(shop.stock, shop.sold) - the offer to buy, or -1 once closed
## (CLOSE, Esc, right-click or a click outside).

signal _chosen(index: int)

const COIN: Texture2D = preload("res://assets/ui/icons/coin.png")
const GOLD_COLOR: Color = Color(1, 0.82, 0.3)
const DIE_VIEW: float = 150.0
const ITEM_WIDTH: float = 400.0

var _content: VBoxContainer


func _ready() -> void:
	UITheme.watch(self)
	layer = 38
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("select") or event.is_action_pressed("cancel"):
			_chosen.emit(-1))
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 18)
	center.add_child(_content)
	InputMode.register_menu(self)
	ButtonPrompt.footer(self, ButtonPrompt.standard("PROMPT_SELECT", "PROMPT_CLOSE"))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_chosen.emit(-1)


## Shows [stock] ([sold] marks what's gone) and waits for a choice.
func choose(stock: Array[Resource], sold: Array[bool]) -> int:
	for child in _content.get_children():
		child.queue_free()
	var gold := SaveManager.run_data.gold
	_content.add_child(_label(tr("SHOP_TITLE"), 67, Color.WHITE))
	var purse := StatIcon.create(COIN, GOLD_COLOR, 36, 32.0)
	purse.set_value(tr("SHOP_GOLD_TO_SPEND") % gold)
	purse.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(purse)
	_content.add_child(_label(tr("SHOP_INFO"), 25, Color(0.65, 0.65, 0.7)))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	_content.add_child(row)
	for i in stock.size():
		var offer := stock[i]
		var price := ShopStock.price(offer)
		var text := tr("SHOP_SOLD") if sold[i] else tr("SHOP_BUY") % price
		# DieCard or EquipmentCard: both have a button and button_pressed
		var card = DieCard.create(offer, DIE_VIEW, text) if offer is DieType else EquipmentCard.create(offer, ITEM_WIDTH, text, 64.0)
		card.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card.button.disabled = sold[i] or gold < price
		if sold[i]:
			card.modulate = Color(1, 1, 1, 0.45)
		card.button_pressed.connect(_chosen.emit.bind(i))
		row.add_child(card)

	var close_button := Button.new()
	close_button.text = tr("BTN_CLOSE")
	close_button.custom_minimum_size = Vector2(200, 50)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_size_override("font_size", 28)
	close_button.pressed.connect(_chosen.emit.bind(-1))
	_content.add_child(close_button)

	visible = true
	_content.modulate.a = 0.0
	create_tween().tween_property(_content, "modulate:a", 1.0, Anim.t(0.15))
	var index: int = await _chosen
	visible = false
	return index


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
