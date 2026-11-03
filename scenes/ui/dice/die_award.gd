class_name DieAward
extends CanvasLayer

## A new die, celebrated in the centre of the screen: it spins in big over a glow in its rarity colour. With room in
## the pool it's added (COLLECT); with a full pool the player picks a die to swap out for it, or leaves it. Every die
## shown - the new one included - can be dragged to turn it or clicked for all six faces.
## Updates the run's pool itself. Runs while the game is paused (chest dice pause it mid-move).
## Use: await award.present(type, "Level clear reward", max_pool_size) - true if the die was taken (collected or swapped in).

signal _finished

const GLOW: Texture2D = preload("res://assets/ui/disc.png")
const TITLE_COLOR: Color = Color(1.0, 0.82, 0.35)
const BIG_VIEW: float = 280.0
## The new die is smaller when the pool is shown under it
const BIG_VIEW_FULL: float = 190.0
const POOL_COLUMNS: int = 5
const POOL_VIEW: float = 96.0
const SCREEN_MARGIN: float = 40.0

var _content: VBoxContainer
var _glow: TextureRect
var _new_type: DieType
var _cards: Array[DieCard] = []
var _swap_index: int = -1
var _swap_button: Button
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


## Shows [type] as a new die from [source], then adds it to the pool, swaps it in or leaves it, as the player chooses.
## Returns true unless it was left.
func present(type: DieType, source: String, max_size: int) -> bool:
	_new_type = type
	_taken = false
	_cards.clear()
	_swap_index = -1
	for child in _content.get_children():
		child.queue_free()
	var run := SaveManager.run_data
	var full := run.dice.size() >= max_size

	var title := _label("NEW DIE!", 56, TITLE_COLOR)
	_content.add_child(title)
	_content.add_child(_label(source, 20, Color(0.7, 0.7, 0.75)))

	var view_size := BIG_VIEW_FULL if full else BIG_VIEW
	var stage := Control.new()
	stage.custom_minimum_size = Vector2.ONE * view_size * 1.25
	stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(stage)
	_glow = TextureRect.new()
	_glow.texture = GLOW
	_glow.modulate = Color(Rarity.COLORS[type.rarity], 0.55)
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.pivot_offset = stage.custom_minimum_size / 2.0
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(_glow)
	var view := DieView.create(type, view_size)
	view.position = Vector2.ONE * view_size * 0.125
	view.size = Vector2.ONE * view_size
	stage.add_child(view)

	_content.add_child(_label(type.display_name, 36, Rarity.COLORS[type.rarity].lightened(0.2)))
	_content.add_child(_label("%s die  ·  click it for all six faces, drag to turn it" % Rarity.Tier.keys()[type.rarity].capitalize(),
		18, Color(0.65, 0.65, 0.7)))

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 20)
	if full:
		_content.add_child(_label("Your pool is full (%d / %d). Choose a die to swap out for it, or leave it." % [run.dice.size(), max_size],
			20, Color.WHITE))
		var types: Array[DieType] = []
		for id in run.dice:
			types.append(Database.get_content("dice", id))
		var grid := DieCard.grid(types, POOL_COLUMNS, POOL_VIEW, "SWAP OUT")
		grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		_content.add_child(grid)
		for i in grid.get_child_count():
			var card: DieCard = grid.get_child(i)
			card.button_pressed.connect(_choose_swap.bind(i))
			_cards.append(card)
		_swap_button = _button("SWAP", _swap)
		_swap_button.disabled = true
		buttons.add_child(_swap_button)
		buttons.add_child(_button("LEAVE IT", _finished.emit))
	else:
		buttons.add_child(_button("COLLECT  (%d / %d)" % [run.dice.size() + 1, max_size], _collect))
	_content.add_child(_gap(6))
	_content.add_child(buttons)

	visible = true
	_content.scale = Vector2.ONE
	_content.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	# Scaled down about its centre if it doesn't fit
	var available := _content.get_viewport_rect().size.y - 2.0 * SCREEN_MARGIN
	_content.pivot_offset = _content.size / 2.0
	var fit := minf(1.0, available / _content.size.y)
	_content.scale = Vector2.ONE * fit * 0.8
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_content, "modulate:a", 1.0, Anim.t(0.2))
	tween.tween_property(_content, "scale", Vector2.ONE * fit, Anim.t(0.45)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	view.spin_in()
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


func _collect() -> void:
	var run := SaveManager.run_data
	run.dice.append(String(_new_type.id))
	run.dice_obtained += 1
	_taken = true
	_finished.emit()


func _choose_swap(index: int) -> void:
	_swap_index = -1 if _swap_index == index else index
	for i in _cards.size():
		_cards[i].selected = i == _swap_index
	_swap_button.disabled = _swap_index == -1
	_swap_button.text = "SWAP  %s → %s" % [_cards[_swap_index].die_type.display_name, _new_type.display_name] if _swap_index != -1 else "SWAP"


## Replaces the chosen die in place, so pool indices (and any dice rolled this turn) stay put.
func _swap() -> void:
	var run := SaveManager.run_data
	run.dice[_swap_index] = String(_new_type.id)
	run.dice_obtained += 1
	_taken = true
	var card := _cards[_swap_index]
	card.pivot_offset = card.size / 2.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(card, "scale", Vector2.ONE * 0.1, Anim.t(0.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(card, "modulate:a", 0.0, Anim.t(0.25))
	await tween.finished
	_finished.emit()


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


func _gap(height: float) -> Control:
	var gap := Control.new()
	gap.custom_minimum_size.y = height
	return gap
