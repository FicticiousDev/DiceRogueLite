class_name BankMenu
extends CanvasLayer

## Opened by clicking the bank: deposit gold (kept between runs) or withdraw banked gold. Each has a slider for the
## amount, starting at all of it. Only one deposit or withdrawal per visit - the run closes the bank after it.
## Use: var amount := await menu.choose() - gold to deposit (positive) or withdraw (negative), 0 if closed without
## either (CLOSE, Esc, right-click or a click outside).

signal _chosen(amount: int)

const COIN: Texture2D = preload("res://assets/ui/icons/coin.png")
const BANK: Texture2D = preload("res://assets/ui/icons/bank.png")
const GOLD_COLOR: Color = Color(1, 0.82, 0.3)
const BANK_COLOR: Color = Color(0.75, 0.8, 0.9)
const SLIDER_WIDTH: float = 360.0

var _content: VBoxContainer


func _ready() -> void:
	layer = 38
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("select") or event.is_action_pressed("cancel"):
			_chosen.emit(0))
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 18)
	center.add_child(_content)
	InputMode.register_menu(self)
	ButtonPrompt.footer(self, ButtonPrompt.standard("Select", "Close", true, [[[&"ui_left", &"ui_right"], "Adjust"]]))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		_chosen.emit(0)


func choose() -> int:
	for child in _content.get_children():
		child.queue_free()
	var gold := SaveManager.run_data.gold
	var banked := SaveManager.progression_data.gold_in_bank
	_content.add_child(_label("BANK", 48, Color.WHITE))
	_content.add_child(_label("Banked gold is kept between runs, for any bank in a later run.\nOne deposit or withdrawal per visit: the bank closes after it.",
		18, Color(0.65, 0.65, 0.7)))
	var balances := HBoxContainer.new()
	balances.alignment = BoxContainer.ALIGNMENT_CENTER
	balances.add_theme_constant_override("separation", 40)
	var carried := StatIcon.create(COIN, GOLD_COLOR, 24, 30.0)
	carried.set_value("%d carried" % gold)
	balances.add_child(carried)
	var stored := StatIcon.create(BANK, BANK_COLOR, 24, 30.0)
	stored.set_value("%d banked" % banked)
	balances.add_child(stored)
	_content.add_child(balances)

	var rows := GridContainer.new()
	rows.columns = 3
	rows.add_theme_constant_override("h_separation", 18)
	rows.add_theme_constant_override("v_separation", 14)
	rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(rows)
	_add_row(rows, "DEPOSIT", gold, 1)
	_add_row(rows, "WITHDRAW", banked, -1)

	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(200, 50)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.pressed.connect(_chosen.emit.bind(0))
	_content.add_child(close_button)

	visible = true
	_content.modulate.a = 0.0
	create_tween().tween_property(_content, "modulate:a", 1.0, Anim.t(0.15))
	var amount: int = await _chosen
	visible = false
	return amount


## A slider from 0 to [most] (starting at [most]), the amount, and a [verb] button that chooses the amount times
## [direction]. Greyed out when there's nothing to move.
func _add_row(rows: GridContainer, verb: String, most: int, direction: int) -> void:
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(SLIDER_WIDTH, 32)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.max_value = most
	slider.step = 1
	slider.value = most
	slider.editable = most > 0
	rows.add_child(slider)
	var amount := _label("", 24, GOLD_COLOR)
	amount.custom_minimum_size.x = 70
	rows.add_child(amount)
	var button := Button.new()
	button.custom_minimum_size = Vector2(240, 50)
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(func(): _chosen.emit(int(slider.value) * direction))
	rows.add_child(button)
	var update := func(value: float):
		amount.text = str(int(value))
		button.text = "%s %d" % [verb, int(value)]
		button.disabled = int(value) == 0
	slider.value_changed.connect(update)
	update.call(slider.value)


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
