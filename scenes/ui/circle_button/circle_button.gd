class_name CircleButton
extends Button

## Round icon button for the controls beside the dice row (abilities, equipment, enemies go first). Greys out when
## disabled, can be highlighted (an armed ability, or one usable right now) with a gold ring, and shows an optional badge
## (uses left, turns to wait). Its tooltip is a [Tooltip].
## Borders: a pale grey ring, and for actives ([member timed]) a blue ring in front of it that fills clockwise from the
## top as the ability recharges ([method set_progress]: 0 just used, 1 ready). Passives ([member passive]) only show
## what they are - they can't be pressed.

const DIAMETER: float = 84.0
const RING: float = 4.0
const BG: Color = Color(0.1, 0.1, 0.14, 0.92)
const BG_HOVER: Color = Color(0.18, 0.18, 0.24, 0.95)
const BG_DISABLED: Color = Color(0.12, 0.12, 0.13, 0.7)
const RING_COLOR: Color = Color(0.78, 0.78, 0.8, 0.85)
const RING_HOVER: Color = Color(0.95, 0.95, 0.97, 1.0)
const RING_DISABLED: Color = Color(0.5, 0.5, 0.52, 0.6)
const TIMER_COLOR: Color = Color(0.25, 0.65, 1.0)
const HIGHLIGHT: Color = Color(1.0, 0.8, 0.35)
const ICON_DISABLED: Color = Color(0.45, 0.45, 0.48, 0.7)

## Shown, never pressed: no recharge ring, no hover bounce
var passive: bool = false:
	set(value):
		passive = value
		button_mask = 0 if passive else MOUSE_BUTTON_MASK_LEFT
		mouse_default_cursor_shape = Control.CURSOR_ARROW if passive else Control.CURSOR_POINTING_HAND
		queue_redraw()
## Draws the blue recharge ring
var timed: bool = false:
	set(value):
		timed = value
		queue_redraw()
## Icon tint while enabled (e.g. an item's rarity)
var icon_color: Color = Color.WHITE:
	set(value):
		icon_color = value
		if is_node_ready():
			_tint_icon()

var _progress: float = 1.0
var _progress_tween: Tween
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
	if not passive:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pivot_offset_ratio = Vector2(0.5, 0.5)
	_tint_icon()
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


## Applies an entry as built by the turn controller: { title, rows, enabled, highlighted, pulse }, optionally badge,
## passive, progress (0-1), icon and icon_color.
func apply(entry: Dictionary) -> void:
	passive = entry.get("passive", false)
	timed = not passive
	if entry.has("icon"):
		icon = entry.icon
	icon_color = entry.get("icon_color", Color.WHITE)
	set_info(entry.title, entry.rows)
	set_badge(entry.get("badge", ""))
	disabled = not entry.get("enabled", true)
	set_highlighted(entry.get("highlighted", false), entry.get("pulse", false))
	set_progress(entry.get("progress", 1.0))


## Tooltip content: [param title] and rows from [method InfoPanel.row].
func set_info(title: String, rows: Array[Dictionary]) -> void:
	Tooltip.set_info(self, title, rows)


func set_badge(text: String) -> void:
	_badge.text = text


## How far the recharge ring is filled (0 just used, 1 ready); eases there unless [param animate] is false.
func set_progress(value: float, animate: bool = true) -> void:
	value = clampf(value, 0.0, 1.0)
	if is_equal_approx(value, _progress) and _progress_tween == null:
		return
	if _progress_tween:
		_progress_tween.kill()
		_progress_tween = null
	if not animate or not is_inside_tree():
		_set_shown_progress(value)
		return
	_progress_tween = create_tween()
	_progress_tween.tween_method(_set_shown_progress, _progress, value, Anim.t(0.4)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	_progress_tween.finished.connect(func(): _progress_tween = null)


## Gold ring; [param pulse] also throbs the button to draw the eye (e.g. a block ability usable against the hit landing now).
func set_highlighted(on: bool, pulse: bool = false) -> void:
	if on != _highlighted:
		_highlighted = on
		queue_redraw()
	if pulse and _pulse == null:
		_pulse = create_tween().set_loops()
		_pulse.tween_property(self, "scale", Vector2.ONE * 1.1, Anim.t(0.35)).set_trans(Tween.TRANS_SINE)
		_pulse.tween_property(self, "scale", Vector2.ONE, Anim.t(0.35)).set_trans(Tween.TRANS_SINE)
	elif not pulse and _pulse:
		_pulse.kill()
		_pulse = null
		scale = Vector2.ONE


func _make_custom_tooltip(_for_text: String) -> Object:
	return Tooltip.make(self)


## Rings, over the background and icon the button has drawn: grey (gold while highlighted), then the recharge ring.
func _draw() -> void:
	var centre := size / 2.0
	var radius := minf(size.x, size.y) / 2.0 - RING / 2.0
	var mode := get_draw_mode()
	var ring := RING_COLOR
	if _highlighted:
		ring = HIGHLIGHT
	elif mode == DRAW_DISABLED:
		ring = RING_DISABLED
	elif not passive and (mode == DRAW_HOVER or mode == DRAW_HOVER_PRESSED):
		ring = RING_HOVER
	draw_arc(centre, radius, 0.0, TAU, 64, ring, RING, true)
	if timed and _progress > 0.0:
		var start := -PI / 2.0
		draw_arc(centre, radius, start, start + TAU * _progress, maxi(int(64 * _progress), 2), TIMER_COLOR, RING, true)


func _set_shown_progress(value: float) -> void:
	_progress = value
	queue_redraw()


func _tint_icon() -> void:
	add_theme_color_override("icon_normal_color", icon_color)
	add_theme_color_override("icon_hover_color", icon_color)
	add_theme_color_override("icon_pressed_color", HIGHLIGHT)
	add_theme_color_override("icon_hover_pressed_color", HIGHLIGHT)
	add_theme_color_override("icon_focus_color", icon_color)
	add_theme_color_override("icon_disabled_color", ICON_DISABLED)


func _bounce(to: float) -> void:
	if _pulse or disabled or passive:
		return
	create_tween().tween_property(self, "scale", Vector2.ONE * to, Anim.t(0.15)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Background circles; the rings are drawn in [method _draw].
func _restyle() -> void:
	add_theme_stylebox_override("normal", _style(BG))
	add_theme_stylebox_override("hover", _style(BG_HOVER))
	add_theme_stylebox_override("pressed", _style(BG_HOVER))
	add_theme_stylebox_override("hover_pressed", _style(BG_HOVER))
	add_theme_stylebox_override("disabled", _style(BG_DISABLED))
	add_theme_stylebox_override("focus", StyleBoxEmpty.new())


func _style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(int(ceil(custom_minimum_size.x / 2.0)))
	style.corner_detail = 16
	style.anti_aliasing = true
	# Padding sets the icon size (expand_icon fits it to the content area)
	style.set_content_margin_all(custom_minimum_size.x * 0.22)
	return style
