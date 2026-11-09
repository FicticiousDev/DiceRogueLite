class_name DieInspector
extends CanvasLayer

## A die's six faces, each named (hover a face for what its symbols do), beside a big copy of the die to turn by
## dragging. Clicking a face turns the die to show it. Opened by clicking a [DieView]; clicking outside the panel,
## right-click, Esc or CLOSE closes it. Runs while the game is paused (die awards from chests pause it).

const VIEW_SIZE: float = 340.0
const FACE_SIZE: float = 64.0
const HIGHLIGHT: Color = Color(1.0, 0.82, 0.35)

var die_type: DieType
var _view: DieView
var _panel: PanelContainer
var _close_button: Button


## Opens an inspector for [type] over everything else.
static func open(from: Node, type: DieType) -> DieInspector:
	var inspector := DieInspector.new()
	inspector.die_type = type
	from.get_tree().root.add_child(inspector)
	return inspector


## A face drawn flat: its carved symbols in their ink on a dark tile with a [rarity] border. Hovering explains it.
static func face_tile(face: DieFace, rarity: Rarity.Tier, tile_size: float, title: String = "") -> PanelContainer:
	var tile := PanelContainer.new()
	var style := StyleBoxFlat.new()
	# Symbol inks read better on dark than on the rarity colour
	style.bg_color = Color(0.17, 0.17, 0.21)
	style.border_color = Rarity.COLORS[rarity]
	style.set_border_width_all(2)
	style.set_corner_radius_all(int(tile_size * 0.16))
	style.set_content_margin_all(3)
	tile.add_theme_stylebox_override("panel", style)
	tile.mouse_filter = Control.MOUSE_FILTER_PASS
	var icon := InfoIcon.new()
	icon.texture = DieFaceTextures.get_textures(face)[0]
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * (tile_size - 6.0)
	icon.set_info(title if title != "" else HelpText.face_summary(face), HelpText.face_rows(face))
	tile.add_child(icon)
	return tile


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("select") or event.is_action_pressed("cancel"):
			close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.08, 0.11, 0.97)
	style.border_color = Rarity.COLORS[die_type.rarity]
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(28)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 32)
	_panel.add_child(row)

	_view = DieView.create(die_type, VIEW_SIZE)
	_view.inspect_on_click = false
	_view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_view)

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 10)
	row.add_child(info)
	var title := _label(die_type.display_name, 36, Rarity.COLORS[die_type.rarity].lightened(0.15))
	info.add_child(title)
	info.add_child(_label("%s die" % Rarity.Tier.keys()[die_type.rarity].capitalize(), 20, Color(0.75, 0.75, 0.8)))
	info.add_child(_label("Drag the die to turn it  ·  click a face to show it  ·  hover a face for details", 16, Color(0.6, 0.6, 0.66)))
	var faces := GridContainer.new()
	faces.columns = 2
	faces.add_theme_constant_override("h_separation", 14)
	faces.add_theme_constant_override("v_separation", 10)
	info.add_child(faces)
	for i in die_type.faces.size():
		faces.add_child(_face_entry(i))
	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(180, 48)
	close_button.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_button.add_theme_font_size_override("font_size", 20)
	close_button.pressed.connect(close)
	info.add_child(close_button)
	_close_button = close_button
	InputMode.register_menu(self, func() -> Control: return _close_button)
	ButtonPrompt.footer(self, ButtonPrompt.standard("Select", "Close"))

	_panel.modulate.a = 0.0
	_panel.scale = Vector2.ONE * 0.85
	await get_tree().process_frame
	_panel.pivot_offset = _panel.size / 2.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_panel, "modulate:a", 1.0, Anim.t(0.15))
	tween.tween_property(_panel, "scale", Vector2.ONE, Anim.t(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		close()


func close() -> void:
	if is_queued_for_deletion():
		return
	queue_free()


## One face: its tile and summary; clicking turns the big die to it.
func _face_entry(index: int) -> Control:
	var face := die_type.faces[index]
	var entry := PanelContainer.new()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(1, 1, 1, 0.04)
	normal.set_corner_radius_all(10)
	normal.set_content_margin_all(6)
	var hover: StyleBoxFlat = normal.duplicate()
	hover.bg_color = Color(HIGHLIGHT, 0.16)
	entry.add_theme_stylebox_override("panel", normal)
	entry.custom_minimum_size.x = 300.0
	entry.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	entry.mouse_entered.connect(func(): entry.add_theme_stylebox_override("panel", hover))
	entry.mouse_exited.connect(func(): entry.add_theme_stylebox_override("panel", normal))
	# Focusable for the gamepad: same look as hovering
	entry.focus_mode = Control.FOCUS_ALL
	entry.focus_entered.connect(func(): entry.add_theme_stylebox_override("panel", hover))
	entry.focus_exited.connect(func(): entry.add_theme_stylebox_override("panel", normal))
	entry.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("select") or event.is_action_pressed("ui_accept"):
			_view.show_face(index))
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	entry.add_child(line)
	line.add_child(face_tile(face, die_type.rarity, FACE_SIZE))
	var label := _label(HelpText.face_summary(face), 20, Color.WHITE)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(label)
	return entry


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
