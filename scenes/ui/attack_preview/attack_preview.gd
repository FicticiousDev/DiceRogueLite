class_name AttackPreview
extends Control

## Shows how the attack being planned adds up, just under the turn plan and as wide as it: each selected die's face
## with its value (and ×2 / ×4 where a crit or ability doubles it), the attack's modifiers and armed actives, then the
## total. Lines wrap to fit. Hovering a target adds its defence, the damage dealt and its health after. Once the target
## is chosen the panel flies into its entry in the turn plan ([method fly_to]). Fed by TurnController._refresh_attack_preview.

## Gap between the turn plan and the panel
const GAP: float = 12.0
const FACE_SIZE: float = 54.0
const GOLD: Color = Color(1.0, 0.82, 0.35)
const SHIELD: Texture2D = preload("res://assets/ui/icons/shield.png")
const HEART: Texture2D = preload("res://assets/ui/icons/heart.png")
const BOW: Texture2D = preload("res://assets/ui/icons/bow.png")

## The turn plan panel it sits under
var anchor: Control
var _panel: PanelContainer
var _rows: VBoxContainer
var _key: String = ""
var _flying: bool = false
var _tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.06, 0.09, 0.9)
	style.border_color = Color(GOLD, 0.6)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(12)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 8)
	_rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_rows)


func _process(_delta: float) -> void:
	if _panel.visible and not _flying and anchor:
		var rect := anchor.get_global_rect()
		_panel.custom_minimum_size.x = rect.size.x
		_panel.size = _panel.get_combined_minimum_size()
		_panel.position = Vector2(rect.position.x, rect.end.y + GAP)


## Shows [ctx], made from [results] (the selected dice, in the context's part order) and the [armed] actives.
## [target] is the hovered enemy (or null) and [target_hp] its health as planned so far.
func show_attack(results: Array[DieResult], ctx: AttackContext, armed: Array[Ability], target: Enemy, target_hp: int) -> void:
	if _flying:
		return
	var key := _make_key(results, ctx, armed, target, target_hp)
	if key == _key and _panel.visible:
		return
	_key = key
	for child in _rows.get_children():
		child.queue_free()

	var line := _flow()
	_rows.add_child(line)
	if results.is_empty():
		line.add_child(_text(tr("PREVIEW_ARMED") % " + ".join(armed.map(func(a: Ability): return a.display_name)), 31, GOLD))
	else:
		for i in results.size():
			if i > 0:
				line.add_child(_text("+", 42, Color(0.7, 0.7, 0.75)))
			line.add_child(_die_part(results[i], ctx, i))
		for chip in _modifier_chips(ctx, results):
			line.add_child(chip)
		for ability in armed:
			line.add_child(_text("+ " + ability.display_name, 28, GOLD))
		line.add_child(_text("=", 42, Color(0.7, 0.7, 0.75)))
		line.add_child(_text(tr("PREVIEW_KILL") if ctx.insta_kill else str(ctx.raw()), 56, Color(1, 0.45, 0.35)))

	if target and results.size() > 0:
		var outcome := _flow()
		_rows.add_child(outcome)
		outcome.add_child(_text("vs %s:" % target.data.display_name, 28, Color(0.85, 0.85, 0.9)))
		if not ctx.insta_kill:
			if ctx.pierces() and target.data.defence > 0:
				outcome.add_child(_text(tr("PREVIEW_BYPASSES_DEFENCE"), 28, Color(0.6, 0.8, 1.0)))
		var damage := ctx.damage()
		outcome.add_child(_text(tr("PREVIEW_DAMAGE") % ("all" if ctx.insta_kill else str(damage)), 31, Color(1, 0.5, 0.4)))
		outcome.add_child(_icon(HEART, Color(1, 0.35, 0.35), 24))
		var after := target_hp - damage
		outcome.add_child(_text("%d → %s" % [target_hp, "dead" if after <= 0 else str(after)], 31, GOLD if after <= 0 else Color.WHITE))

	if not _panel.visible:
		_panel.visible = true
		_panel.modulate.a = 1.0
		_panel.scale = Vector2.ONE * 0.85
		_panel.pivot_offset = _panel.get_combined_minimum_size() / 2.0
		_animate().tween_property(_panel, "scale", Vector2.ONE, Anim.t(0.25)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_preview() -> void:
	if _flying or not _panel.visible:
		return
	_panel.visible = false
	_key = ""


## The attack was planned: flies the panel into entry [index] of [list], shrinking and fading, then hides it.
func fly_to(list: ActionList, index: int) -> void:
	if not _panel.visible:
		return
	_flying = true
	# The list rebuilds this frame; its new entry has a size the next
	await get_tree().process_frame
	await get_tree().process_frame
	var target := list.entry_rect(index)
	_panel.pivot_offset = Vector2.ZERO
	var scale_to := clampf(target.size.x / maxf(_panel.size.x, 1.0), 0.2, 1.0)
	var tween := _animate().set_parallel(true)
	tween.tween_property(_panel, "position", target.position, Anim.t(0.4)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_panel, "scale", Vector2.ONE * scale_to, Anim.t(0.4)).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_panel, "modulate:a", 0.0, Anim.t(0.2)).set_delay(Anim.t(0.25))
	await tween.finished
	_panel.visible = false
	_panel.scale = Vector2.ONE
	_panel.modulate.a = 1.0
	_key = ""
	_flying = false


## One die: its face and value, ×n if doubled.
func _die_part(result: DieResult, ctx: AttackContext, part: int) -> Control:
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 2)
	var tile := DieInspector.face_tile(result.display_face(), result.die_type.rarity, FACE_SIZE)
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.get_child(0).mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	box.add_child(tile)
	var multiplier: int = ctx.part_multipliers[part] if part < ctx.part_multipliers.size() else 1
	var value: int = ctx.parts[part] if part < ctx.parts.size() else result.value()
	var text := tr("PREVIEW_KILL") if result.face().has(Symbol.Type.INSTA_KILL) and ctx.insta_kill else str(value)
	if multiplier > 1:
		text += " ×%d" % multiplier
	var label := _text(text, 28, GOLD if multiplier > 1 else Color.WHITE)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	return box


## The attack's modifiers as icon + text chips: stun, poison, pierce, range, area.
func _modifier_chips(ctx: AttackContext, results: Array[DieResult]) -> Array[Control]:
	var chips: Array[Control] = []
	if ctx.stun:
		chips.append(_chip(Symbol.ICONS[Symbol.Type.STUN], Symbol.INK[Symbol.Type.STUN], "stun", true))
	if ctx.poison:
		chips.append(_chip(Symbol.ICONS[Symbol.Type.POISON], Symbol.INK[Symbol.Type.POISON], "poison", true))
	if ctx.penetrate > 0:
		chips.append(_chip(Symbol.ICONS[Symbol.Type.PENETRATE], Symbol.INK[Symbol.Type.PENETRATE].lightened(0.3), tr("PREVIEW_PIERCE") % ctx.penetrate, true))
	# Combined dice keep only the range they all share
	var range_bonus := -1
	var range_lost := false
	for result in results:
		var face_range := result.face().count(Symbol.Type.RANGE)
		range_lost = range_lost or (range_bonus != -1 and face_range != range_bonus)
		range_bonus = face_range if range_bonus == -1 else mini(range_bonus, face_range)
	if range_bonus > 0:
		chips.append(_chip(BOW, Color(0.95, 0.85, 0.6), tr("PREVIEW_RANGE_BONUS") % range_bonus, false))
	if range_lost:
		chips.append(_chip(BOW, Color(0.6, 0.6, 0.65), tr("PREVIEW_RANGE_LOST"), false))
	if ctx.aoe_tiles.size() > 0:
		chips.append(_text(tr("PREVIEW_AREA"), 28, GOLD))
	return chips


func _chip(texture: Texture2D, color: Color, text: String, mask: bool) -> Control:
	var box := _line()
	box.add_theme_constant_override("separation", 4)
	var icon := _icon(texture, color.lightened(0.3), 28)
	if mask:
		var material := ShaderMaterial.new()
		material.shader = InfoPanel.MASK_SHADER
		icon.material = material
	box.add_child(icon)
	box.add_child(_text(text, 25, color.lightened(0.4)))
	return box


## A centred line of parts that wraps onto more lines when it's wider than the panel.
func _flow() -> HFlowContainer:
	var flow := HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 6)
	flow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return flow


func _line() -> HBoxContainer:
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 10)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


func _icon(texture: Texture2D, color: Color, icon_size: float) -> TextureRect:
	var icon := TextureRect.new()
	icon.texture = texture
	icon.modulate = color
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2.ONE * icon_size
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return icon


func _text(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _animate() -> Tween:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	return _tween


func _make_key(results: Array[DieResult], ctx: AttackContext, armed: Array[Ability], target: Enemy, target_hp: int) -> String:
	return "%s|%s|%s|%s|%d|%d|%s" % [results.map(func(r: DieResult): return "%d:%d" % [r.index, r.value()]), ctx.parts, ctx.part_multipliers,
		armed.map(func(a: Ability): return a.id), target.get_instance_id() if target else 0, target_hp, ctx.damage()]
