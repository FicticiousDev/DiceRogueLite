class_name CircleButton
extends Button

## Round icon button for the controls beside the dice row (abilities, enemies go first). Greys out when disabled, can be
## highlighted (an armed ability, or one usable right now) with a gold ring, and shows an optional badge (uses left,
## turns to wait). Its tooltip is an [InfoPanel], like [InfoIcon]'s.

const DIAMETER: float = 84.0
const RING: int = 4
const BG: Color = Color(0.1, 0.1, 0.14, 0.92)
const BG_HOVER: Color = Color(0.18, 0.18, 0.24, 0.95)
const BG_DISABLED: Color = Color(0.12, 0.12, 0.13, 0.7)
const RING_COLOR: Color = Color(0.85, 0.85, 0.95, 0.8)
const RING_DISABLED: Color = Color(0.4, 0.4, 0.42, 0.6)
const HIGHLIGHT: Color = Color(1.0, 0.8, 0.35)
const ICON_DISABLED: Color = Color(0.45, 0.45, 0.48, 0.7)

var info_title: String
var info_rows: Array[Dictionary] = []

var _highlighted: bool = false
var _badge: Label
var _pulse: Tween


static func create(texture: Texture2D, diameter: float = DIAMETER) -> CircleButton:
	var button := CircleButton.new()
	button.icon = texture
	button.custom_minimum_size = Vector2.ONE * diameter
	return button


func _ready() -> void:
	expand_icon = true
	icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset_ratio = Vector2(0.5, 0.5)
	add_theme_color_override("icon_normal_color", Color.WHITE)
	add_theme_color_override("icon_hover_color", Color.WHITE)
	add_theme_color_override("icon_pressed_color", HIGHLIGHT)
	add_theme_color_override("icon_focus_color", Color.WHITE)
	add_theme_color_override("icon_disabled_color", ICON_DISABLED)
	_badge = Label.new()
	_badge.add_theme_font_size_override("font_size", 22)
	_badge.add_theme_constant_override("outline_size", 6)
	_badge.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_badge.anchor_left = 0.0
	_badge.anchor_right = 1.0
	_badge.anchor_top = 1.0
	_badge.anchor_bottom = 1.0
	_badge.offset_top = -24.0
	_badge.offset_bottom = 6.0
	add_child(_badge)
	_restyle()
	mouse_entered.connect(func(): _bounce(1.08))
	mouse_exited.connect(func(): _bounce(1.0))


## Tooltip content: [param title] and rows from [method InfoPanel.row].
func set_info(title: String, rows: Array[Dictionary]) -> void:
	info_title = title
	info_rows = rows
	# Built-in tooltips only open when there's some text
	tooltip_text = title


func set_badge(text: String) -> void:
	_badge.text = text


## Gold ring; [param pulse] also throbs the button to draw the eye (e.g. a block ability usable against the hit landing now).
func set_highlighted(on: bool, pulse: bool = false) -> void:
	if on != _highlighted:
		_highlighted = on
		_restyle()
	if pulse and _pulse == null:
		_pulse = create_tween().set_loops()
		_pulse.tween_property(self, "scale", Vector2.ONE * 1.1, Anim.t(0.35)).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(self, "scale", Vector2.ONE, Anim.t(0.35)).set_trans(Tween.TRANS_SINE)
	elif not pulse and _pulse:
		_pulse.kill()
		_pulse = null
		scale = Vector2.ONE


func _make_custom_tooltip(_for_text: String) -> Object:
	return InfoPanel.content(info_title, info_rows)


func _bounce(to: float) -> void:
	if _pulse or disabled:
		return
	create_tween().tween_property(self, "scale", Vector2.ONE * to, Anim.t(0.15)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _restyle() -> void:
	var ring := HIGHLIGHT if _highlighted else RING_COLOR
	add_theme_stylebox_override("normal", _style(BG, ring))
	add_theme_stylebox_override("hover", _style(BG_HOVER, HIGHLIGHT if _highlighted else Color.WHITE))
	add_theme_stylebox_override("pressed", _style(BG_HOVER, HIGHLIGHT))
	add_theme_stylebox_override("hover_pressed", _style(BG_HOVER, HIGHLIGHT))
	add_theme_stylebox_override("disabled", _style(BG_DISABLED, RING_DISABLED))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style(bg: Color, ring: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = ring
	style.set_border_width_all(RING)
	style.set_corner_radius_all(int(ceil(custom_minimum_size.x / 2.0)))
	style.corner_detail = 16
	style.anti_aliasing = true
	# Padding sets the icon size (expand_icon fits it to the content area)
	style.set_content_margin_all(custom_minimum_size.x * 0.22)
	return style
