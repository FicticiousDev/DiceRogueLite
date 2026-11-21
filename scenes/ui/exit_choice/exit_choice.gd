class_name ExitChoice
extends CanvasLayer

## Shown over the middle of the screen once a cleared level has folded away: one button per level the run map leads on
## to, with its type's symbol in its biome's colour, the type and the biome. It has to be answered; the map ([M]) can be
## opened over it to help choose.
## Use: var target := await choice.choose(links) - the chosen map node.

signal _chosen(target: int)

const DISC: Texture2D = preload("res://assets/ui/disc.png")
const OPTION_SIZE: Vector2 = Vector2(640, 116)
const BADGE_SIZE: float = 88.0
## Delay between the options popping in
const STAGGER: float = 0.07

var _panel: VBoxContainer
var _options: VBoxContainer
var _first: Button


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
	_panel.add_theme_constant_override("separation", 26)
	center.add_child(_panel)
	var title := Label.new()
	title.text = tr("EXIT_CHOICE_TITLE")
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 60)
	_panel.add_child(title)
	_options = VBoxContainer.new()
	_options.add_theme_constant_override("separation", 16)
	_panel.add_child(_options)
	InputMode.register_menu(self, func() -> Control: return _first)
	ButtonPrompt.footer(self, ButtonPrompt.standard("PROMPT_SELECT", "", true, [[[&"map"], "PROMPT_MAP"]]))


## Shows a button for each of [links] (map node indices, in the order given) and waits for one to be chosen.
func choose(links: Array[int]) -> int:
	for child in _options.get_children():
		child.queue_free()
	_first = null
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
	var out := create_tween()
	out.tween_property(_panel, "modulate:a", 0.0, Anim.t(0.15))
	await out.finished
	visible = false
	return target


## A wide button: the badge (disc in the biome's colour, the level type's symbol on it), then the type over the biome.
func _option(run: RunData, target: int) -> Button:
	var biome := RunMap.biome(run, target)
	var type := RunMap.level(run, target).type
	var button := Button.new()
	button.custom_minimum_size = OPTION_SIZE
	button.pressed.connect(func(): _chosen.emit(target))

	var row := HBoxContainer.new()
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 24.0
	row.offset_right = -24.0
	row.alignment = BoxContainer.ALIGNMENT_BEGIN
	row.add_theme_constant_override("separation", 28)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(row)

	var disc := TextureRect.new()
	disc.texture = DISC
	disc.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	disc.custom_minimum_size = Vector2.ONE * BADGE_SIZE
	disc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	disc.modulate = biome.color
	disc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(disc)
	var icon := TextureRect.new()
	icon.texture = LevelData.ICONS[type]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.size = Vector2.ONE * BADGE_SIZE * 0.55
	icon.position = (Vector2.ONE * BADGE_SIZE - icon.size) / 2.0
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	disc.add_child(icon)

	var text := VBoxContainer.new()
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text)
	text.add_child(_label(tr(LevelData.NAMES[type]), 44, Color.WHITE))
	text.add_child(_label(biome.display_name, 30, biome.color))
	return button


func _label(content: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = content
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Scales [button] up from nothing after [delay].
func _pop_in(button: Button, delay: float) -> void:
	button.pivot_offset_ratio = Vector2(0.5, 0.5)
	button.scale = Vector2.ONE * 0.01
	var tween := create_tween()
	tween.tween_property(button, "scale", Vector2.ONE, Anim.t(0.35)).set_delay(Anim.t(delay)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
