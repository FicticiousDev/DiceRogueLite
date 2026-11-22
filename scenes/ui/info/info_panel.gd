class_name InfoPanel
extends PanelContainer

## A title and rows of icon + explanation: every tooltip ([Tooltip]), the enemy details and item cards.
## Rows are made with [method row] (a null icon leaves the text on its own); mask rows draw die-symbol height masks as
## flat icons. The frame is the theme's TooltipPanel, which built-in tooltips draw too.

const MASK_SHADER: Shader = preload("res://shaders/mask_icon.gdshader")
const TITLE_COLOR: Color = Color(1.0, 0.85, 0.45)


static func row(icon: Texture2D, color: Color, text: String, mask: bool = false) -> Dictionary:
	return { "icon": icon, "color": color, "text": text, "mask": mask }


## A framed panel. [width] is the text column width ([fit]: at most, narrower for short text); [font_size] scales icons too.
static func create(title: String, rows: Array[Dictionary], width: float = 380.0, font_size: int = 25, fit: bool = false) -> InfoPanel:
	var panel := InfoPanel.new()
	panel.theme = UITheme.BASE
	panel.theme_type_variation = &"TooltipPanel"
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content(title, rows, width, font_size, fit))
	return panel


## The panel's contents without a frame (built-in tooltips supply their own).
static func content(title: String, rows: Array[Dictionary], width: float = 380.0, font_size: int = 25, fit: bool = false) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.theme = UITheme.BASE
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", int(font_size * 0.5))
	if title != "":
		var heading := Label.new()
		heading.text = title
		heading.add_theme_font_size_override("font_size", int(font_size * 1.3))
		heading.add_theme_color_override("font_color", TITLE_COLOR)
		box.add_child(heading)
	for entry in rows:
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", int(font_size * 0.6))
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if entry.icon:
			var icon := TextureRect.new()
			icon.texture = entry.icon
			icon.modulate = entry.color
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2.ONE * font_size * 1.6
			icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			if entry.mask:
				var material := ShaderMaterial.new()
				material.shader = MASK_SHADER
				icon.material = material
			line.add_child(icon)
		var label := Label.new()
		label.text = entry.text
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_size_override("font_size", font_size)
		line.add_child(label)
		box.add_child(line)
		# Parented first, so the label resolves the theme's font
		label.custom_minimum_size.x = _text_width(label, width, font_size) if fit else width
	return box


## [param label]'s text width on one line per paragraph, capped at [param width].
static func _text_width(label: Label, width: float, font_size: int) -> float:
	var font := label.get_theme_font(&"font")
	var natural := font.get_multiline_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	return minf(width, ceilf(natural) + 2.0)
