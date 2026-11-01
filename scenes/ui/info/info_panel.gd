class_name InfoPanel
extends PanelContainer

## A title and rows of icon + explanation, used for tooltips (dice, player statuses) and the enemy details.
## Rows are made with [method row]; mask rows draw die-symbol height masks as flat icons.

const MASK_SHADER: Shader = preload("res://shaders/mask_icon.gdshader")
const TITLE_COLOR: Color = Color(1.0, 0.85, 0.45)


static func row(icon: Texture2D, color: Color, text: String, mask: bool = false) -> Dictionary:
	return { "icon": icon, "color": color, "text": text, "mask": mask }


## A framed panel. [width] is the text column width; [font_size] scales icons too.
static func create(title: String, rows: Array[Dictionary], width: float = 380.0, font_size: int = 18) -> InfoPanel:
	var panel := InfoPanel.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.07, 0.1, 0.95)
	style.border_color = Color(1, 1, 1, 0.25)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(14)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content(title, rows, width, font_size))
	return panel


## The panel's contents without a frame (built-in tooltips supply their own).
static func content(title: String, rows: Array[Dictionary], width: float = 380.0, font_size: int = 18) -> VBoxContainer:
	var box := VBoxContainer.new()
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
		label.custom_minimum_size.x = width
		label.add_theme_font_size_override("font_size", font_size)
		line.add_child(label)
		box.add_child(line)
	return box
