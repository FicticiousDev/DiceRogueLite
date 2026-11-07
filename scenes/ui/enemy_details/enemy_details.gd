class_name EnemyDetails
extends CanvasLayer

## Opened by clicking an enemy while not assigning dice: the piece on the left, every stat explained on the right.
## Click anywhere, right-click or Esc to close.

const HEART: Texture2D = preload("res://assets/ui/icons/heart.png")
const SWORD: Texture2D = preload("res://assets/ui/icons/sword.png")
const SHIELD: Texture2D = preload("res://assets/ui/icons/shield.png")
const MOVE: Texture2D = preload("res://assets/ui/icons/move.png")
const BOW: Texture2D = preload("res://assets/ui/icons/bow.png")
const LIGHTNING: Texture2D = preload("res://assets/ui/icons/lightning.png")
const STUN: Texture2D = preload("res://assets/ui/icons/stun.png")
const POISON: Texture2D = preload("res://assets/ui/icons/poison.png")
const FREEZE: Texture2D = preload("res://assets/ui/icons/freeze.png")
const FIRE: Texture2D = preload("res://assets/ui/icons/fire.png")
const CROWN: Texture2D = preload("res://assets/ui/icons/crown.png")
const COIN: Texture2D = preload("res://assets/ui/icons/coin.png")
const PORTRAIT_SIZE: float = 320.0

var _content: HBoxContainer


func _ready() -> void:
	layer = 36
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.05, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("select") or event.is_action_pressed("cancel"):
			close())
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_content = HBoxContainer.new()
	_content.add_theme_constant_override("separation", 40)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(_content)


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("cancel"):
		get_viewport().set_input_as_handled()
		close()


func open(enemy: Enemy) -> void:
	for child in _content.get_children():
		child.queue_free()
	var data := enemy.data
	var portrait := TextureRect.new()
	portrait.texture = data.texture
	portrait.modulate = data.tint
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2.ONE * PORTRAIT_SIZE
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(portrait)
	_content.add_child(InfoPanel.create(data.display_name, rows(enemy), 560.0, 24))
	visible = true
	_content.pivot_offset = _content.size / 2.0
	_content.modulate.a = 0.0
	create_tween().tween_property(_content, "modulate:a", 1.0, Anim.t(0.15))


func close() -> void:
	visible = false


## Every stat of [enemy], explained.
static func rows(enemy: Enemy) -> Array[Dictionary]:
	var data := enemy.data
	var result: Array[Dictionary] = []
	if enemy.stunned:
		result.append(InfoPanel.row(STUN, Color(1.0, 0.75, 0.3), HelpText.ENEMY_STUNNED))
	if enemy.poisoned:
		result.append(InfoPanel.row(POISON, Color(0.55, 1.0, 0.45), HelpText.ENEMY_POISONED))
	if data.is_boss:
		result.append(InfoPanel.row(CROWN, Color(1.0, 0.82, 0.3), "Boss: can't be insta-killed – an insta-kill face hits it for %d with a crit instead." % AttackContext.BOSS_INSTA_KILL_DAMAGE))
		for line in data.description.split("\n", false):
			result.append(InfoPanel.row(CROWN, Color(1.0, 0.82, 0.3), line))
		if data.stun_immune:
			result.append(InfoPanel.row(STUN, Color(0.7, 0.7, 0.75), HelpText.STUN_IMMUNE))
	var health := "Health %d / %d." % [enemy.hp, data.hp]
	if data.segments > 1:
		health += " Split into %d segments." % data.segments
	result.append(InfoPanel.row(HEART, Color(1, 0.35, 0.35), health))
	if data.shield > 0:
		result.append(InfoPanel.row(SHIELD, Color(0.55, 0.85, 1.0), "Ice shield %d / %d: damage hits the shield first and the rest carries over to health. Recovers %d in any round it takes no damage." % [enemy.shield, data.shield, data.shield_regen]))
	var attack := "Attack %d damage per hit. %d%% chance to crit (double damage), %d%% chance to miss." % [
		data.attack, roundi(data.crit_chance * 100), roundi(data.miss_chance * 100)]
	if data.attacks_per_turn > 1:
		attack += " Attacks %d times in its turn, each rolled and blocked separately. A strike back uses up one of them that round." % data.attacks_per_turn
	result.append(InfoPanel.row(SWORD, Symbol.INK[Symbol.Type.ATTACK].lightened(0.3), attack))
	if data.applies_stun:
		result.append(InfoPanel.row(STUN, Color(1.0, 0.75, 0.3), "Stunning hits: a hit that damages you stuns you – you can't act until the next round (in its turn: you lose your next turn)."))
	if data.applies_freeze:
		result.append(InfoPanel.row(FREEZE, Color(0.55, 0.85, 1.0), HelpText.FREEZING_HITS))
	if data.applies_fire:
		result.append(InfoPanel.row(FIRE, Color(1.0, 0.55, 0.2), HelpText.FIRE_HITS))
	if data.applies_poison:
		result.append(InfoPanel.row(POISON, Color(0.55, 1.0, 0.45), "Poisonous hits: a hit that damages you poisons you – 1 damage at the start of each of your turns until a heal cures it."))
	result.append(InfoPanel.row(SHIELD, Color(0.45, 0.7, 1.0), "Defence %d: every hit it takes is reduced by %d." % [data.defence, data.defence] if data.defence > 0 else "Defence 0: takes the full damage of every hit."))
	result.append(InfoPanel.row(MOVE, Symbol.INK[Symbol.Type.MOVE].lightened(0.4), "Move %d: tiles it can move each turn; difficult terrain costs more." % data.move))
	if data.attack_range > 1:
		result.append(InfoPanel.row(BOW, Color(0.95, 0.85, 0.6), "Range %d: attacks from up to %d tiles away with line of sight." % [data.attack_range, data.attack_range]))
	else:
		result.append(InfoPanel.row(BOW, Color(0.95, 0.85, 0.6), "Melee: attacks adjacent tiles only."))
	if data.attacks_first:
		result.append(InfoPanel.row(LIGHTNING, Color(1.0, 0.65, 0.25), HelpText.ATTACKS_FIRST))
	result.append(InfoPanel.row(COIN, Color(1, 0.82, 0.3), "Worth %d gold." % TurnController.kill_gold(data)))
	return result
