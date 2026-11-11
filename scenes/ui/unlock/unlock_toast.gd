class_name UnlockToast
extends CanvasLayer

## Announces completed unlock challenges: a banner drops in at the top centre ("UNLOCKED", what it unlocked, how it
## was earned), holds, then rises away. Several queue up and show one after another. Runs while the game is paused.
## Use: toast.announce(challenges)

const HOLD: float = 3.5
const WIDTH: float = 560.0
const GOLD: Color = Color(1.0, 0.82, 0.35)

var _queue: Array[UnlockChallenge] = []
var _showing: bool = false


func _ready() -> void:
	UITheme.watch(self)
	layer = 56
	process_mode = Node.PROCESS_MODE_ALWAYS


func announce(challenges: Array[UnlockChallenge]) -> void:
	_queue.append_array(challenges)
	if not _showing:
		_show_next()


func _show_next() -> void:
	_showing = true
	while _queue.size() > 0:
		await _show(_queue.pop_front())
	_showing = false


func _show(challenge: UnlockChallenge) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.07, 0.1, 0.94)
	style.border_color = GOLD
	style.set_border_width_all(3)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)
	box.add_child(_label(tr("UNLOCK_TITLE"), 28, GOLD))
	box.add_child(_label(challenge.reward_name(), 42, Color.WHITE))
	box.add_child(_label(challenge.description, 24, Color(0.8, 0.8, 0.85)))
	add_child(panel)
	panel.custom_minimum_size.x = WIDTH
	await get_tree().process_frame
	var screen := panel.get_viewport_rect().size
	var shown_y := 24.0
	panel.position = Vector2((screen.x - panel.size.x) / 2.0, -panel.size.y - 10.0)
	var tween := create_tween()
	tween.tween_property(panel, "position:y", shown_y, Anim.t(0.45)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(HOLD)
	tween.tween_property(panel, "position:y", -panel.size.y - 10.0, Anim.t(0.3)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	await tween.finished
	panel.queue_free()


func _label(text: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label
