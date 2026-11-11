class_name StatIcon
extends HBoxContainer

## Icon + value pair used by the top bar and enemy info.

const ICON_SIZE: float = 22.0

var icon: TextureRect
var label: Label


static func create(texture: Texture2D, color: Color, font_size: int = 25, icon_size: float = ICON_SIZE) -> StatIcon:
	var stat := StatIcon.new()
	stat.add_theme_constant_override("separation", 3)
	stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stat.icon = TextureRect.new()
	stat.icon.texture = texture
	stat.icon.modulate = color
	stat.icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stat.icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	stat.icon.custom_minimum_size = Vector2(icon_size, icon_size)
	stat.add_child(stat.icon)
	stat.label = Label.new()
	stat.label.add_theme_font_size_override("font_size", font_size)
	stat.label.add_theme_constant_override("outline_size", 6)
	stat.label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	stat.add_child(stat.label)
	return stat


## Sets the value, popping if it changed.
func set_value(text: String, color: Color = Color.WHITE) -> void:
	label.add_theme_color_override("font_color", color)
	if label.text == text:
		return
	var changed := label.text != ""
	label.text = text
	if changed:
		pivot_offset = size / 2.0
		scale = Vector2.ONE * 1.35
		create_tween().tween_property(self, "scale", Vector2.ONE, Anim.t(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
