class_name UnlockReveal
extends CanvasLayer

## The celebration for collecting a Mystery piece. A big question mark winds up - shaking harder and harder, swelling
## and drawing sparks in - then bursts in a flash to reveal the die or item that's now unlocked for good. Runs while
## the game is paused. The unlock itself is the caller's job (ProgressionData.unlock).
## Use: await reveal.present(content) - content is a DieType or EquipmentData.

signal _finished

const GLOW: Texture2D = preload("res://assets/ui/disc.png")
## Soft glow for the halo and sparks
var _soft: Texture2D = Mystery.soft_glow()
const TITLE_COLOR: Color = Color(1.0, 0.82, 0.35)
const MARK_COLOR: Color = Mystery.COLOR
const STAGE_SIZE: float = 360.0
const VIEW_SIZE: float = 250.0
const ICON_SIZE: float = 190.0
## Seconds of shaking before the burst
const WIND_UP: float = 1.8
const SCREEN_MARGIN: float = 40.0

var _content: VBoxContainer
var _flash: ColorRect
var _stage: Control
var _glow: TextureRect
var _halo: TextureRect
var _glow_speed: float = 0.6


func _ready() -> void:
	UITheme.watch(self)
	layer = 52
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 10)
	center.add_child(_content)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_flash)
	# CONTINUE takes the focus itself once it is enabled
	InputMode.register_menu(self)
	ButtonPrompt.footer(self, ButtonPrompt.standard("PROMPT_CONTINUE", "", false))


func _process(delta: float) -> void:
	if visible and _glow:
		_glow.rotation += delta * _glow_speed


## Winds up, bursts and shows [content] (DieType or EquipmentData) until CONTINUE is pressed.
func present(content: Resource) -> void:
	for child in _content.get_children():
		child.queue_free()
	var rarity: int = content.get("rarity")
	var rarity_color: Color = Rarity.COLORS[rarity]

	# Everything is laid out up front (the reveal hidden) so the question mark sits where the prize will appear
	var title := _label(tr("UNLOCK_TITLE"), 84, TITLE_COLOR)
	title.modulate.a = 0.0
	_content.add_child(title)
	_stage = Control.new()
	_stage.custom_minimum_size = Vector2.ONE * STAGE_SIZE
	_stage.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_content.add_child(_stage)
	_glow = TextureRect.new()
	_glow.texture = GLOW
	_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	_glow.pivot_offset = _stage.custom_minimum_size / 2.0
	_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_glow.modulate = Color(MARK_COLOR, 0.3)
	_glow_speed = 0.6
	_halo = TextureRect.new()
	_halo.texture = _soft
	_halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_halo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_halo.pivot_offset = _stage.custom_minimum_size / 2.0
	_halo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_halo.modulate = Color(MARK_COLOR, 0.25)
	_stage.add_child(_halo)
	_stage.add_child(_glow)
	var mark := TextureRect.new()
	mark.texture = Mystery.TEXTURE
	mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.size = Vector2.ONE * STAGE_SIZE * 0.6
	mark.position = (Vector2.ONE * STAGE_SIZE - mark.size) / 2.0
	mark.pivot_offset = mark.size / 2.0
	_stage.add_child(mark)
	var gather := _gather_sparks()
	_stage.add_child(gather)
	var burst := _burst_sparks(rarity_color)
	_stage.add_child(burst)

	var reveal: Array[Control] = []
	reveal.append(_label(content.get("display_name"), 53, rarity_color.lightened(0.2)))
	var item := content as EquipmentData
	var kind: String = item.kind() if item else tr("DICE_KIND") % Rarity.display_name(rarity)
	reveal.append(_label(kind, 25, Color(0.65, 0.65, 0.7)))
	if item:
		var rows := InfoPanel.content("", item.info_rows(), 560.0, 19)
		rows.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		reveal.append(rows)
	reveal.append(_label(tr("UNLOCK_FOR_GOOD"), 28, Color.WHITE))
	var button := Button.new()
	button.text = tr("BTN_CONTINUE")
	button.custom_minimum_size = Vector2(240, 54)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 31)
	button.disabled = true
	button.pressed.connect(_finished.emit)
	reveal.append(button)
	for node in reveal:
		node.modulate.a = 0.0
		_content.add_child(node)

	visible = true
	offset = Vector2.ZERO
	_content.scale = Vector2.ONE
	_content.modulate.a = 0.0
	await get_tree().process_frame
	await get_tree().process_frame
	# Scaled down about its centre if it doesn't fit
	var available := _content.get_viewport_rect().size.y - 2.0 * SCREEN_MARGIN
	_content.pivot_offset = _content.size / 2.0
	var fit := minf(1.0, available / _content.size.y)
	_content.scale = Vector2.ONE * fit
	create_tween().tween_property(_content, "modulate:a", 1.0, Anim.t(0.25))

	# The question mark pops in, then winds up
	mark.scale = Vector2.ONE * 0.2
	var pop := create_tween()
	pop.tween_property(mark, "scale", Vector2.ONE, Anim.t(0.5)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await pop.finished
	gather.emitting = true
	var wind := create_tween()
	var rest := mark.position
	wind.tween_method(_wind_up.bind(mark, rest), 0.0, 1.0, Anim.t(WIND_UP))
	await wind.finished
	gather.emitting = false
	# A last breath in...
	var inhale := create_tween().set_parallel(true)
	inhale.tween_property(mark, "scale", Vector2.ONE * 0.55, Anim.t(0.14)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	inhale.tween_property(mark, "position", rest, Anim.t(0.14))
	inhale.tween_property(_glow, "scale", Vector2.ONE * 0.5, Anim.t(0.14)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	inhale.tween_property(_halo, "scale", Vector2.ONE * 0.4, Anim.t(0.14)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await inhale.finished

	# ...and the burst
	mark.visible = false
	burst.restart()
	_shockwave(Color.WHITE, 0.0)
	_shockwave(rarity_color, 0.08)
	_shake()
	_flash.color.a = 0.95
	create_tween().tween_property(_flash, "color:a", 0.0, Anim.t(0.6)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_glow.modulate = Color(rarity_color, 0.6)
	_glow_speed = 0.6
	_halo.modulate = Color(rarity_color, 0.9)
	var glow_in := create_tween().set_parallel(true)
	glow_in.tween_property(_glow, "scale", Vector2.ONE, Anim.t(0.7)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	glow_in.tween_property(_halo, "scale", Vector2.ONE * 1.8, Anim.t(0.5)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	glow_in.chain().tween_property(_halo, "modulate:a", 0.35, Anim.t(0.8))
	var prize := _prize(content)
	_stage.add_child(prize)
	_stage.move_child(prize, 2)
	if prize is DieView:
		(prize as DieView).spin_in()
	var title_pop := create_tween().set_parallel(true)
	title.pivot_offset = title.size / 2.0
	title.scale = Vector2.ONE * 0.3
	title_pop.tween_property(title, "modulate:a", 1.0, Anim.t(0.15))
	title_pop.tween_property(title, "scale", Vector2.ONE, Anim.t(0.6)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	for i in reveal.size():
		create_tween().tween_property(reveal[i], "modulate:a", 1.0, Anim.t(0.3)).set_delay(Anim.t(0.25 + 0.1 * i))
	await get_tree().create_timer(Anim.t(0.5)).timeout
	button.disabled = false
	button.grab_focus()

	await _finished
	var out := create_tween().set_parallel(true)
	out.tween_property(_content, "modulate:a", 0.0, Anim.t(0.2))
	out.tween_property(_content, "scale", Vector2.ONE * fit * 0.85, Anim.t(0.2)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await out.finished
	visible = false
	_glow = null
	_halo = null
	_stage = null
	for child in _content.get_children():
		child.queue_free()


## One step of the wind-up, [t] 0 to 1: the mark shakes harder, swells and throbs faster and the glow brightens and spins up.
func _wind_up(t: float, mark: Control, rest: Vector2) -> void:
	var shake := 2.0 + 20.0 * t * t
	mark.position = rest + Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	mark.rotation = randf_range(-0.15, 0.15) * t
	mark.scale = Vector2.ONE * (1.0 + 0.3 * t) * (1.0 + 0.07 * t * sin(t * t * 70.0))
	mark.modulate = Color.WHITE.lerp(MARK_COLOR.lightened(0.7), t)
	_glow.modulate = Color(MARK_COLOR, lerpf(0.3, 1.0, t))
	_glow.scale = Vector2.ONE * (1.0 + 0.4 * t)
	_halo.modulate = Color(MARK_COLOR, lerpf(0.25, 0.9, t))
	_halo.scale = Vector2.ONE * (1.0 + 0.9 * t)
	_glow_speed = 0.6 + 9.0 * t * t


## The unlocked die (turnable, click for its faces) or item icon, centred on the stage.
func _prize(content: Resource) -> Control:
	var prize: Control
	if content is DieType:
		prize = DieView.create(content as DieType, VIEW_SIZE)
		prize.size = Vector2.ONE * VIEW_SIZE
	else:
		prize = EquipmentCard.icon(content as EquipmentData, ICON_SIZE)
		prize.size = Vector2.ONE * ICON_SIZE
		prize.pivot_offset = prize.size / 2.0
		prize.scale = Vector2.ONE * 0.2
		create_tween().tween_property(prize, "scale", Vector2.ONE, Anim.t(0.6)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	prize.position = (Vector2.ONE * STAGE_SIZE - prize.size) / 2.0
	return prize


## Sparks drawn in from a wide circle to the centre while it winds up.
func _gather_sparks() -> CPUParticles2D:
	var sparks := _sparks(56, 0.65)
	sparks.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	sparks.emission_sphere_radius = STAGE_SIZE * 0.85
	sparks.radial_accel_min = -1500.0
	sparks.radial_accel_max = -1200.0
	sparks.scale_amount_min = 14.0 / _soft.get_width()
	sparks.scale_amount_max = 30.0 / _soft.get_width()
	sparks.color_ramp = _ramp([Color(MARK_COLOR, 0.0), MARK_COLOR.lightened(0.5), Color.WHITE])
	return sparks


## One shot of sparks flying out from the centre.
func _burst_sparks(color: Color) -> CPUParticles2D:
	var sparks := _sparks(110, 1.2)
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.spread = 180.0
	sparks.initial_velocity_min = 350.0
	sparks.initial_velocity_max = 1250.0
	sparks.damping_min = 500.0
	sparks.damping_max = 900.0
	sparks.scale_amount_min = 16.0 / _soft.get_width()
	sparks.scale_amount_max = 48.0 / _soft.get_width()
	sparks.color_ramp = _ramp([Color.WHITE, color.lightened(0.3), Color(color, 0.0)])
	return sparks


func _sparks(amount: int, lifetime: float) -> CPUParticles2D:
	var sparks := CPUParticles2D.new()
	sparks.emitting = false
	sparks.amount = amount
	sparks.lifetime = lifetime
	sparks.texture = _soft
	sparks.gravity = Vector2.ZERO
	sparks.position = Vector2.ONE * STAGE_SIZE / 2.0
	return sparks


static func _ramp(colors: Array[Color]) -> Gradient:
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	ramp.colors = PackedColorArray(colors)
	return ramp


## A ring racing out from the centre of the stage and fading, after [delay] seconds.
func _shockwave(color: Color, delay: float) -> void:
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.border_color = color
	style.set_border_width_all(10)
	style.set_corner_radius_all(1000)
	var ring := Panel.new()
	ring.add_theme_stylebox_override("panel", style)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.size = Vector2.ONE * 200.0
	ring.position = (Vector2.ONE * STAGE_SIZE - ring.size) / 2.0
	ring.pivot_offset = ring.size / 2.0
	ring.scale = Vector2.ONE * 0.2
	_stage.add_child(ring)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE * 4.0, Anim.t(0.6)).set_delay(Anim.t(delay)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring, "modulate:a", 0.0, Anim.t(0.6)).set_delay(Anim.t(delay)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.finished.connect(ring.queue_free)


## A short, fading shake of the whole popup.
func _shake() -> void:
	var tween := create_tween()
	for i in 8:
		var strength := 18.0 * (1.0 - i / 8.0)
		tween.tween_property(self, "offset", Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), Anim.t(0.035))
	tween.tween_property(self, "offset", Vector2.ZERO, Anim.t(0.05))


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label
