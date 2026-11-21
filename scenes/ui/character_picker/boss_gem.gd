class_name BossGem
extends Control

## A socket on a character card for one biome's boss (CharacterPicker): empty until the character has beaten that boss,
## then holding a faceted gem in the biome's colour, glowing and slowly pulsing. Hover for the boss's name.

const RADIUS: float = 13.0
## Room around the socket for its rim
const PADDING: float = 3.0
## How far the glow reaches, in radii from the centre, and the rings it's built from
const GLOW_REACH: float = 2.1
const GLOW_RINGS: int = 7
const GLOW_ALPHA: float = 0.08
## Seconds from bright to dim
const PULSE_TIME: float = 1.4
const DIM: float = 0.5
const SOCKET_COLOR: Color = Color(0.03, 0.03, 0.05)
const RIM_COLOR: Color = Color(0.45, 0.41, 0.35)
## Where the light on the facets comes from (top left)
const LIGHT: Vector2 = Vector2(-0.6, -0.8)

var color: Color = Color.WHITE
var filled: bool = false
## Glow strength, pulsing between [constant DIM] and 1
var glow: float = 1.0:
	set(value):
		glow = value
		queue_redraw()
## Share of a pulse to start at, so a row of gems shimmers rather than pulsing together
var _phase: float = 0.0


static func create(gem_color: Color, is_filled: bool, tooltip: String, phase: float = 0.0) -> BossGem:
	var gem := BossGem.new()
	gem.color = gem_color
	gem.filled = is_filled
	gem.tooltip_text = tooltip
	gem.custom_minimum_size = Vector2.ONE * 2.0 * (RADIUS + PADDING)
	# Clicks still reach the card
	gem.mouse_filter = Control.MOUSE_FILTER_PASS
	gem._phase = phase
	return gem


func _ready() -> void:
	if not filled:
		return
	var tween := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "glow", DIM, PULSE_TIME)
	tween.tween_property(self, "glow", 1.0, PULSE_TIME)
	tween.custom_step(_phase * 2.0 * PULSE_TIME)


func _draw() -> void:
	var centre := size / 2.0
	if filled:
		# Halo behind the socket, outer rings first
		for i in GLOW_RINGS:
			var radius := lerpf(RADIUS * GLOW_REACH, RADIUS, float(i) / GLOW_RINGS)
			draw_circle(centre, radius, Color(color, GLOW_ALPHA * glow), true, -1.0, true)
	_draw_socket(centre)
	if filled:
		_draw_gem(centre)


## A dark recess with a bevelled rim: shadowed along the top inside, lit along the bottom lip.
func _draw_socket(centre: Vector2) -> void:
	draw_circle(centre, RADIUS, SOCKET_COLOR, true, -1.0, true)
	draw_arc(centre, RADIUS, 0.0, TAU, 40, RIM_COLOR, 2.5, true)
	draw_arc(centre, RADIUS - 2.0, PI * 1.1, PI * 1.9, 16, Color(0, 0, 0, 0.7), 2.0, true)
	draw_arc(centre, RADIUS - 2.0, PI * 0.15, PI * 0.85, 16, RIM_COLOR.lightened(0.35), 1.5, true)


## A hexagonal cut gem: a flat table in the middle, six facets around it shaded by [constant LIGHT], a glint.
func _draw_gem(centre: Vector2) -> void:
	var outer := RADIUS * 0.78
	var table := outer * 0.5
	var base := color.lightened(0.25 * (glow - DIM))
	var rim := PackedVector2Array()
	var top := PackedVector2Array()
	for k in 6:
		var direction := Vector2.from_angle(-PI / 2.0 + k * TAU / 6.0)
		rim.append(centre + direction * outer)
		top.append(centre + direction * table)
	for k in 6:
		var next := (k + 1) % 6
		var facing := Vector2.from_angle(-PI / 2.0 + (k + 0.5) * TAU / 6.0).dot(LIGHT.normalized())
		var shade := base.lightened(0.4 * facing) if facing > 0.0 else base.darkened(-0.5 * facing)
		draw_colored_polygon(PackedVector2Array([rim[k], rim[next], top[next], top[k]]), shade)
	draw_colored_polygon(top, base.lightened(0.2))
	var outline := rim.duplicate()
	outline.append(rim[0])
	draw_polyline(outline, color.darkened(0.6), 1.2, true)
	# Glint on the table, brighter as the gem pulses up
	draw_circle(centre + Vector2(-table * 0.35, -table * 0.4), table * 0.32, Color(1, 1, 1, 0.55 + 0.35 * glow), true, -1.0, true)
