class_name EnemyHealthBar
extends Control

## An enemy's health bar, drawn into a viewport by [EnemyStatsBar] just above the piece. Current health sits in a
## circle at the start of the bar (a crown above it for bosses) and defence in a shield at the end; health the plan
## will take off shows in the planned colour. The whole group spans the control's width.

const CROWN: Texture2D = preload("res://assets/ui/icons/crown.png")
const SHIELD: Texture2D = preload("res://assets/ui/icons/shield.png")
const FILL_COLOR: Color = Color(0.92, 0.27, 0.24)
const PLANNED_COLOR: Color = Color(1.0, 0.65, 0.25)
const DEFENCE_COLOR: Color = Color(0.45, 0.7, 1.0)
const CROWN_COLOR: Color = Color(1.0, 0.82, 0.3)
const BACK_COLOR: Color = Color(0.06, 0.06, 0.09, 0.9)
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.95)
const CIRCLE_RADIUS: float = 19.0
const BAR_HEIGHT: float = 13.0
const SHIELD_SIZE: float = 40.0
const CROWN_HEIGHT: float = 20.0
const OUTLINE: float = 3.0
const FONT_SIZE: int = 25
const DEFENCE_FONT_SIZE: int = 23
## Room around everything so the circle can pop without clipping
const TEXT_OUTLINE: int = 10
const MARGIN: float = 4.0
const POP_SCALE: float = 1.2

var enemy: Enemy
var _hp: int = -1
var _preview_hp: int = -1
var _pop: float = 1.0:
	set(value):
		_pop = value
		queue_redraw()


## Height the control needs; the width is set by [EnemyStatsBar] to match the piece.
static func height(is_boss: bool) -> float:
	return ceilf(MARGIN * 2.0 + maxf((CIRCLE_RADIUS + OUTLINE) * 2.0, SHIELD_SIZE) + (CROWN_HEIGHT if is_boss else 0.0))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if not is_instance_valid(enemy) or (enemy.hp == _hp and enemy.preview_hp == _preview_hp):
		return
	if _hp != -1 and enemy.hp != _hp:
		_pop = POP_SCALE
		create_tween().tween_property(self, "_pop", 1.0, Anim.t(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hp = enemy.hp
	_preview_hp = maxi(enemy.preview_hp, 0)
	queue_redraw()


func _draw() -> void:
	if _hp < 0:
		return
	var data := enemy.data
	var centre := Vector2(MARGIN + CIRCLE_RADIUS + OUTLINE, size.y - MARGIN - maxf(CIRCLE_RADIUS + OUTLINE, SHIELD_SIZE / 2.0))
	var shield := Rect2(size.x - MARGIN - SHIELD_SIZE, centre.y - SHIELD_SIZE / 2.0, SHIELD_SIZE, SHIELD_SIZE)

	# Bar: runs from under the circle to under the shield; the fill starts at the circle's edge
	var bar := Rect2(centre.x, centre.y - BAR_HEIGHT / 2.0, shield.get_center().x - centre.x, BAR_HEIGHT)
	_rounded_rect(bar.grow(OUTLINE), OUTLINE_COLOR)
	_rounded_rect(bar, BACK_COLOR)
	var fill_start := centre.x + CIRCLE_RADIUS
	var fill_length := shield.position.x + SHIELD_SIZE * 0.2 - fill_start
	var max_hp := maxi(data.hp, 1)
	var current := fill_length * clampf(float(_hp) / max_hp, 0.0, 1.0)
	var planned := fill_length * clampf(float(_preview_hp) / max_hp, 0.0, 1.0)
	if current > planned:
		_rounded_rect(Rect2(fill_start - BAR_HEIGHT, bar.position.y, current + BAR_HEIGHT, BAR_HEIGHT), PLANNED_COLOR)
	if planned > 0.0:
		_rounded_rect(Rect2(fill_start - BAR_HEIGHT, bar.position.y, planned + BAR_HEIGHT, BAR_HEIGHT), FILL_COLOR)

	# Defence
	_outlined_icon(SHIELD, shield, DEFENCE_COLOR)
	_centred_text(str(data.defence), shield.get_center() + Vector2(0.0, -1.0), DEFENCE_FONT_SIZE)

	# Current health, scaled about its centre when popping; boss crown above
	draw_set_transform(centre * (1.0 - _pop), 0.0, Vector2.ONE * _pop)
	draw_circle(centre, CIRCLE_RADIUS + OUTLINE, OUTLINE_COLOR)
	draw_circle(centre, CIRCLE_RADIUS, Color(BACK_COLOR, 1.0))
	draw_arc(centre, CIRCLE_RADIUS - 2.5, 0.0, TAU, 40, PLANNED_COLOR if _preview_hp != _hp else FILL_COLOR, 3.0, true)
	_centred_text(str(_hp), centre, FONT_SIZE)
	draw_set_transform(Vector2.ZERO)
	if data.is_boss:
		var crown_width := CROWN_HEIGHT * 1.35
		_outlined_icon(CROWN, Rect2(centre.x - crown_width / 2.0, centre.y - CIRCLE_RADIUS - OUTLINE - CROWN_HEIGHT + 2.0, crown_width, CROWN_HEIGHT), CROWN_COLOR)


func _centred_text(text: String, centre: Vector2, font_size: int) -> void:
	var font := get_theme_default_font()
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var baseline := centre + Vector2(-text_size.x / 2.0, font.get_ascent(font_size) - text_size.y / 2.0)
	draw_string_outline(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, TEXT_OUTLINE, OUTLINE_COLOR)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)


## Icon with a dark outline: a black copy drawn slightly larger behind it.
func _outlined_icon(texture: Texture2D, rect: Rect2, color: Color) -> void:
	for offset: Vector2 in [Vector2(-2, 0), Vector2(2, 0), Vector2(0, -2), Vector2(0, 2)]:
		draw_texture_rect(texture, Rect2(rect.position + offset, rect.size), false, OUTLINE_COLOR)
	draw_texture_rect(texture, rect, false, color)


func _rounded_rect(rect: Rect2, color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(rect.size.y / 2.0))
	style.anti_aliasing = true
	draw_style_box(style, rect)
