class_name ExitChoice
extends CanvasLayer

## Shown over the middle of the screen once a cleared level has folded away: a row of open gates, one per level the run map
## leads on to, each in its biome's colour with its level type's symbol at the top of the arch. The highlighted gate (mouse,
## arrow keys or gamepad) grows in place and names its level in a tooltip. It has to be answered; the map ([M]) can be opened
## over it to help choose.
## Use: var target := await choice.choose(links) - the chosen map node.

signal _chosen(target: int)

const GATE: Texture2D = preload("res://assets/pieces/gate_open.png")
const DISC: Texture2D = preload("res://assets/ui/disc.png")
const GATE_SIZE: Vector2 = Vector2(300, 300)
const GATE_SEPARATION: int = 72
## Centre of the level type's symbol (the top of the arch's opening) and its size, as fractions of the gate
const SYMBOL_CENTER: Vector2 = Vector2(0.5, 0.3)
const SYMBOL_SIZE: float = 0.2
## Dark disc behind the symbol so it reads against the light in the arch
const BACKING_SIZE: float = 0.28
const BACKING_COLOR: Color = Color(0.0, 0.0, 0.0, 0.55)
const HIGHLIGHT_SCALE: float = 1.18
## Gates that aren't highlighted are dimmed to this
const DIMMED: Color = Color(0.72, 0.72, 0.72)
## Delay between the gates popping in
const STAGGER: float = 0.07
## Seconds a gate must be highlighted before its tooltip fades in
const TIP_DELAY: float = 0.2
## Gap between a gate and its tooltip
const TIP_GAP: float = 10.0

var _panel: VBoxContainer
var _options: HBoxContainer
var _first: Button
var _highlighted: Button
## Each option's gate (the part that scales) and tooltip
var _gates: Dictionary[Button, Control] = {}
var _tips: Dictionary[Button, InfoPanel] = {}
var _gate_tweens: Dictionary[Control, Tween] = {}
var _tip: InfoPanel
var _tip_tween: Tween


func _ready() -> void:
	UITheme.watch(self)
	# Under the map (35), so it can be opened alongside
	layer = 30
	visible = false
	# Dims the board but lets the HUD (settings, main menu) take clicks
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 40)
	center.add_child(_panel)
	var title := Label.new()
	title.text = tr("EXIT_CHOICE_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	_panel.add_child(title)
	_options = HBoxContainer.new()
	_options.alignment = BoxContainer.ALIGNMENT_CENTER
	_options.add_theme_constant_override("separation", GATE_SEPARATION)
	_panel.add_child(_options)
	InputMode.register_menu(self, func() -> Control: return _first)
	ButtonPrompt.footer(self, ButtonPrompt.standard("PROMPT_SELECT", "", true, [[[&"map"], "PROMPT_MAP"]]))


func _process(_delta: float) -> void:
	if visible and _tip and _highlighted:
		_place_tip()


## Shows a gate for each of [links] (map node indices, left to right in the order given) and waits for one to be chosen.
func choose(links: Array[int]) -> int:
	for child in _options.get_children():
		child.queue_free()
	for tip in _tips.values():
		tip.queue_free()
	_gates.clear()
	_tips.clear()
	_gate_tweens.clear()
	_first = null
	_highlighted = null
	_tip = null
	var run := SaveManager.run_data
	var buttons: Array[Button] = []
	for target in links:
		var button := _option(run, target)
		_options.add_child(button)
		buttons.append(button)
	if buttons.size() > 0:
		_first = buttons[0]

	visible = true
	_panel.modulate.a = 0.0
	create_tween().tween_property(_panel, "modulate:a", 1.0, Anim.t(0.2))
	for i in buttons.size():
		_pop_in(buttons[i], i * STAGGER)
	var target: int = await _chosen
	_highlight(null)
	var out := create_tween()
	out.tween_property(_panel, "modulate:a", 0.0, Anim.t(0.15))
	await out.finished
	visible = false
	return target


# ===========================================================================================================================================
# Gates
# ===========================================================================================================================================


## A borderless button holding the gate in the biome's colour, with the level type's symbol at the top of the arch.
func _option(run: RunData, target: int) -> Button:
	var biome := RunMap.biome(run, target)
	var type := RunMap.level(run, target).type
	var button := Button.new()
	button.custom_minimum_size = GATE_SIZE
	button.flat = true
	var empty := StyleBoxEmpty.new()
	for style in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		button.add_theme_stylebox_override(style, empty)
	button.pressed.connect(func(): _chosen.emit(target))
	button.focus_entered.connect(_highlight.bind(button))
	button.focus_exited.connect(_on_focus_exited.bind(button))
	# The mouse highlights through the focus, so it and the arrows / gamepad share one highlight
	button.mouse_entered.connect(button.grab_focus)
	button.mouse_exited.connect(_on_mouse_exited.bind(button))

	var gate := TextureRect.new()
	gate.texture = GATE
	gate.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gate.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gate.set_anchors_preset(Control.PRESET_FULL_RECT)
	gate.pivot_offset_ratio = Vector2(0.5, 0.5)
	gate.self_modulate = biome.color
	gate.modulate = DIMMED
	gate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(gate)
	var backing := _symbol_part(DISC, BACKING_SIZE)
	backing.modulate = BACKING_COLOR
	gate.add_child(backing)
	gate.add_child(_symbol_part(LevelData.ICONS[type], SYMBOL_SIZE))
	_gates[button] = gate

	var rows: Array[Dictionary] = [InfoPanel.row(DISC, biome.color, biome.display_name)]
	var tip := InfoPanel.create(tr(LevelData.NAMES[type]), rows, 200.0, 24)
	tip.visible = false
	add_child(tip)
	_tips[button] = tip
	return button


## A square of [param size] (a fraction of the gate) centred on [constant SYMBOL_CENTER], scaling with the gate.
func _symbol_part(texture: Texture2D, size: float) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.anchor_left = SYMBOL_CENTER.x - size / 2.0
	rect.anchor_right = SYMBOL_CENTER.x + size / 2.0
	rect.anchor_top = SYMBOL_CENTER.y - size / 2.0
	rect.anchor_bottom = SYMBOL_CENTER.y + size / 2.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Scales [button] up from nothing after [delay].
func _pop_in(button: Button, delay: float) -> void:
	button.pivot_offset_ratio = Vector2(0.5, 0.5)
	button.scale = Vector2.ONE * 0.01
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, Anim.t(0.35)).set_delay(Anim.t(delay)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ===========================================================================================================================================
# Highlight
# ===========================================================================================================================================


## Raises [param button]'s gate (lowering the last one) and shows its tooltip; null clears the highlight.
func _highlight(button: Button) -> void:
	if button == _highlighted:
		return
	if _highlighted and _gates.has(_highlighted):
		_raise(_gates[_highlighted], false)
	_highlighted = button
	if button:
		_raise(_gates[button], true)
	_show_tip(_tips.get(button))


func _on_focus_exited(button: Button) -> void:
	if button == _highlighted:
		_highlight(null)


## Leaving a gate with the mouse drops its highlight (on a gamepad the focus stays put).
func _on_mouse_exited(button: Button) -> void:
	if not InputMode.is_gamepad() and button.has_focus():
		button.release_focus()


func _raise(gate: Control, raised: bool) -> void:
	if _gate_tweens.has(gate):
		_gate_tweens[gate].kill()
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(gate, "scale", Vector2.ONE * (HIGHLIGHT_SCALE if raised else 1.0), Anim.t(0.18))
	tween.tween_property(gate, "modulate", Color.WHITE if raised else DIMMED, Anim.t(0.18))
	_gate_tweens[gate] = tween


# ===========================================================================================================================================
# Tooltip
# ===========================================================================================================================================


## Hides the current tooltip and fades in [param tip] (if any) after [constant TIP_DELAY].
func _show_tip(tip: InfoPanel) -> void:
	if _tip_tween:
		_tip_tween.kill()
	if _tip:
		_tip.visible = false
	_tip = tip
	if tip == null:
		return
	tip.modulate.a = 0.0
	tip.visible = true
	_place_tip()
	_tip_tween = create_tween()
	_tip_tween.tween_property(tip, "modulate:a", 1.0, Anim.t(0.15)).set_delay(Anim.t(TIP_DELAY))


## Centres the tooltip under the highlighted gate (as scaled), kept on screen.
func _place_tip() -> void:
	var rect := _gates[_highlighted].get_global_rect()
	var screen := get_viewport().get_visible_rect().size
	var at := Vector2(rect.get_center().x - _tip.size.x / 2.0, rect.end.y + TIP_GAP)
	_tip.position = at.clamp(Vector2.ZERO, screen - _tip.size)
