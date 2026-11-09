class_name ChallengeBanner
extends CanvasLayer

## Challenge levels: announces the turn limit in the centre of the screen as the level starts, then sits under the
## top bar counting the turns. Gold once the level is cleared in time, red once the limit has passed.

const STAR: Texture2D = preload("res://assets/ui/icons/star.png")
const GOLD: Color = Color(1.0, 0.82, 0.3)
const WARN: Color = Color(1.0, 0.6, 0.25)
const FAIL: Color = Color(1.0, 0.35, 0.3)
## Where the banner settles: its top centre, in canvas pixels (just under the top bar)
const DOCK: Vector2 = Vector2(960, 54)

## True / false once the challenge is decided (read by Phase 14 rewards), null until then
var won: Variant = null
var turn: TurnController
var limit: int = 0

var _panel: PanelContainer
var _title: Label
var _status: Label


func _ready() -> void:
	layer = 20
	visible = false
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.1, 0.92)
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(12)
	style.content_margin_left = 18
	style.content_margin_right = 22
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_panel.add_child(row)
	var icon := TextureRect.new()
	icon.texture = STAR
	icon.modulate = GOLD
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(44, 44)
	row.add_child(icon)
	var text := VBoxContainer.new()
	text.add_theme_constant_override("separation", 0)
	row.add_child(text)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.modulate = GOLD
	text.add_child(_title)
	_status = Label.new()
	_status.add_theme_font_size_override("font_size", 26)
	text.add_child(_status)


## Shows the banner for a level with [turn_limit] turns (0 hides it), announcing it in the centre first. Awaitable.
func start(turn_controller: TurnController, turn_limit: int) -> void:
	turn = turn_controller
	limit = turn_limit
	won = null
	visible = limit > 0
	if not visible:
		return
	_title.text = tr("BANNER_CHALLENGE")
	_status.text = tr("BANNER_DEFEAT_WITHIN") % limit
	_status.modulate = Color.WHITE
	await get_tree().process_frame
	var viewport := _panel.get_viewport_rect().size
	_panel.pivot_offset = _panel.size / 2.0
	_panel.position = (viewport - _panel.size) / 2.0
	_panel.scale = Vector2.ONE * 0.3
	_panel.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_panel, "scale", Vector2.ONE * 1.7, Anim.t(0.5)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "modulate:a", 1.0, Anim.t(0.25))
	await tween.finished
	await get_tree().create_timer(Anim.t(1.4)).timeout
	tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_panel, "scale", Vector2.ONE, Anim.t(0.5))
	tween.tween_property(_panel, "position", DOCK - Vector2(_panel.size.x / 2.0, 0.0), Anim.t(0.5))
	await tween.finished


func _process(_delta: float) -> void:
	if not visible or turn == null or _panel.scale != Vector2.ONE:
		return
	var current := maxi(turn.turn_number, 1)
	if won == null and turn.state == TurnController.State.LEVEL_CLEAR:
		won = current <= limit
	elif won == null and current > limit:
		won = false
	if won == true:
		_set_status(tr("BANNER_COMPLETE"), tr("BANNER_CLEARED_ON_TURN") % [current, limit], GOLD)
	elif won == false:
		_set_status(tr("BANNER_FAILED"), tr("BANNER_TURN_LIMIT_PASSED") % limit, FAIL)
	elif current == limit:
		_set_status(tr("BANNER_LAST_TURN"), tr("BANNER_TURN_OF") % [current, limit], WARN)
	else:
		_set_status(tr("BANNER_CHALLENGE"), tr("BANNER_TURN_OF_LEFT") % [current, limit, limit - current], Color.WHITE)


func _set_status(title: String, status: String, color: Color) -> void:
	if _status.text == status and _title.text == title:
		return
	_title.text = title
	_status.text = status
	_status.modulate = color
	_title.modulate = color if color != Color.WHITE else GOLD
	_panel.get_theme_stylebox("panel").border_color = _title.modulate
	# Re-centre on the dock as the width changes
	_panel.reset_size()
	_panel.position = DOCK - Vector2(_panel.size.x / 2.0, 0.0)
