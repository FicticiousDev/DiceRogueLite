class_name EnemyHealthBar
extends Control

## An enemy's health bar, drawn into a viewport by [EnemyStatsBar] just above the piece. Current health sits in a
## circle at the start of the bar (a crown above it for bosses) and the retaliation sword at the end. Above the bar
## ride the thin ice shield bar and, above that, the defence bar: one segment per point. What the plan will take off
## shows in the planned colour. The whole group spans the control's width.

const CROWN: Texture2D = preload("res://assets/ui/icons/crown.png")
const SWORD: Texture2D = preload("res://assets/ui/icons/sword.png")
const FILL_COLOR: Color = Color(0.92, 0.27, 0.24)
const PLANNED_COLOR: Color = Color(1.0, 0.65, 0.25)
const DEFENCE_COLOR: Color = Color(0.45, 0.7, 1.0)
const ICE_COLOR: Color = Color(0.6, 0.88, 1.0)
const TICK_COLOR: Color = Color(0.0, 0.0, 0.0, 0.9)
const ICE_HEIGHT: float = 7.0
const DEFENCE_HEIGHT: float = 10.0
## Gap between a bar and the one below it
const LAYER_GAP: float = 2.0
const RETALIATE_COLOR: Color = Color(1.0, 0.65, 0.25)
const NO_RETALIATE_COLOR: Color = Color(0.55, 0.55, 0.6)
const SLASH_COLOR: Color = Color(1.0, 0.3, 0.25)
const CROWN_COLOR: Color = Color(1.0, 0.82, 0.3)
const BACK_COLOR: Color = Color(0.06, 0.06, 0.09, 0.9)
const OUTLINE_COLOR: Color = Color(0.0, 0.0, 0.0, 0.95)
const CIRCLE_RADIUS: float = 19.0
const BAR_HEIGHT: float = 13.0
## The retaliation sword's slot at the end of the bar
const SLOT_SIZE: float = 40.0
const CROWN_HEIGHT: float = 20.0
const OUTLINE: float = 3.0
const FONT_SIZE: int = 25
## Room around everything so the circle can pop without clipping
const TEXT_OUTLINE: int = 10
const MARGIN: float = 4.0
const POP_SCALE: float = 1.2

var enemy: Enemy
var _hp: int = -1
var _preview_hp: int = -1
var _shield: int = -1
var _preview_shield: int = -1
var _defence: int = -1
var _preview_defence: int = -1
var _max_defence: int = -1
## Retaliation sword: -1 hidden, 0 won't strike back, 1 will
var _retaliation: int = -2
var _pop: float = 1.0:
	set(value):
		_pop = value
		queue_redraw()


## Height the control needs for [data]; the width is set by [EnemyStatsBar] to match the piece.
static func height(data: EnemyData) -> float:
	var circle := CIRCLE_RADIUS + OUTLINE
	var above := circle + (CROWN_HEIGHT if data.is_boss else 0.0)
	var stack := BAR_HEIGHT / 2.0 + 2.0
	if data.shield > 0:
		stack += ICE_HEIGHT + LAYER_GAP
	if data.defence > 0:
		stack += DEFENCE_HEIGHT + LAYER_GAP
	return ceilf(MARGIN * 2.0 + maxf(circle, SLOT_SIZE / 2.0) + maxf(above, stack))


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if not is_instance_valid(enemy):
		return
	var preview_shield := maxi(enemy.preview_shield, 0)
	var preview_defence := maxi(enemy.preview_defence, 0)
	var retaliation := (1 if enemy.can_retaliate else 0) if enemy.show_retaliation else -1
	if enemy.hp == _hp and enemy.preview_hp == _preview_hp and enemy.shield == _shield and preview_shield == _preview_shield \
			and enemy.defence == _defence and preview_defence == _preview_defence and enemy.data.defence == _max_defence and retaliation == _retaliation:
		return
	if _hp != -1 and enemy.hp != _hp:
		_pop = POP_SCALE
		create_tween().tween_property(self, "_pop", 1.0, Anim.t(0.3)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_hp = enemy.hp
	_preview_hp = maxi(enemy.preview_hp, 0)
	_shield = enemy.shield
	_preview_shield = preview_shield
	_defence = enemy.defence
	_preview_defence = preview_defence
	_max_defence = enemy.data.defence
	_retaliation = retaliation
	queue_redraw()


func _draw() -> void:
	if _hp < 0:
		return
	var data := enemy.data
	var centre := Vector2(MARGIN + CIRCLE_RADIUS + OUTLINE, size.y - MARGIN - maxf(CIRCLE_RADIUS + OUTLINE, SLOT_SIZE / 2.0))
	var slot := Rect2(size.x - MARGIN - SLOT_SIZE, centre.y - SLOT_SIZE / 2.0, SLOT_SIZE, SLOT_SIZE)

	# Bar: runs from under the circle to under the retaliation sword; the fill starts at the circle's edge
	var bar := Rect2(centre.x, centre.y - BAR_HEIGHT / 2.0, slot.get_center().x - centre.x, BAR_HEIGHT)
	_rounded_rect(bar.grow(OUTLINE), OUTLINE_COLOR)
	_rounded_rect(bar, BACK_COLOR)
	var fill_start := centre.x + CIRCLE_RADIUS
	var fill_length := slot.position.x + SLOT_SIZE * 0.2 - fill_start
	var max_hp := maxi(data.hp, 1)
	var current := fill_length * clampf(float(_hp) / max_hp, 0.0, 1.0)
	var planned := fill_length * clampf(float(_preview_hp) / max_hp, 0.0, 1.0)
	if current > planned:
		_rounded_rect(Rect2(fill_start - BAR_HEIGHT, bar.position.y, current + BAR_HEIGHT, BAR_HEIGHT), PLANNED_COLOR)
	if planned > 0.0:
		_rounded_rect(Rect2(fill_start - BAR_HEIGHT, bar.position.y, planned + BAR_HEIGHT, BAR_HEIGHT), FILL_COLOR)

	# Segment dividers
	for k in range(1, data.segments):
		var x := fill_start + fill_length * k / data.segments
		draw_line(Vector2(x, bar.position.y), Vector2(x, bar.end.y), TICK_COLOR, 2.0)

	# Ice shield: a thin bar riding on top of the health bar
	var top := bar.position.y
	if data.shield > 0:
		var ice := Rect2(fill_start, top - ICE_HEIGHT - LAYER_GAP, fill_length, ICE_HEIGHT)
		top = ice.position.y
		_rounded_rect(ice.grow(2.0), OUTLINE_COLOR)
		_rounded_rect(ice, BACK_COLOR)
		var ice_now := ice.size.x * clampf(float(_shield) / data.shield, 0.0, 1.0)
		var ice_planned := ice.size.x * clampf(float(_preview_shield) / data.shield, 0.0, 1.0)
		if ice_now > ice_planned:
			_rounded_rect(Rect2(ice.position, Vector2(ice_now, ICE_HEIGHT)), PLANNED_COLOR)
		if ice_planned > 0.0:
			_rounded_rect(Rect2(ice.position, Vector2(ice_planned, ICE_HEIGHT)), ICE_COLOR)

	# Defence: one segment per point, above whatever bar is below it
	if _max_defence > 0:
		var armour := Rect2(fill_start, top - DEFENCE_HEIGHT - LAYER_GAP, fill_length, DEFENCE_HEIGHT)
		_rounded_rect(armour.grow(2.0), OUTLINE_COLOR)
		_rounded_rect(armour, BACK_COLOR)
		var segment := armour.size.x / _max_defence
		var defence_now := segment * clampi(_defence, 0, _max_defence)
		var defence_planned := segment * clampi(_preview_defence, 0, _max_defence)
		if defence_now > defence_planned:
			_rounded_rect(Rect2(armour.position, Vector2(defence_now, DEFENCE_HEIGHT)), PLANNED_COLOR)
		if defence_planned > 0.0:
			_rounded_rect(Rect2(armour.position, Vector2(defence_planned, DEFENCE_HEIGHT)), DEFENCE_COLOR)
		for k in range(1, _max_defence):
			var x := armour.position.x + segment * k
			draw_line(Vector2(x, armour.position.y), Vector2(x, armour.end.y), TICK_COLOR, 2.0)

	# Retaliation sword, struck through when it won't strike back
	if _retaliation >= 0:
		var color := RETALIATE_COLOR if _retaliation == 1 else NO_RETALIATE_COLOR
		_outlined_icon(SWORD, slot, color)
		if _retaliation == 0:
			draw_line(slot.position, slot.end, OUTLINE_COLOR, 8.0, true)
			draw_line(slot.position, slot.end, SLASH_COLOR, 4.0, true)

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
