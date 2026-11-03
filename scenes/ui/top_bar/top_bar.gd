class_name TopBar
extends PanelContainer

## Status bar along the top: character and ability charges, HP, gold, banked gold (greyed while the bank is empty)
## equipped items (hover for what they do; actives show their uses left) and the dice pool - the pool's rarest die,
## turning, with the pool size; clicking it opens the pool viewer.

signal pool_pressed

const HEART: Texture2D = preload("res://assets/ui/icons/heart.png")
const COIN: Texture2D = preload("res://assets/ui/icons/coin.png")
const BANK: Texture2D = preload("res://assets/ui/icons/bank.png")
const BOW: Texture2D = preload("res://assets/ui/icons/bow.png")
const STUN: Texture2D = preload("res://assets/ui/icons/stun.png")
const POISON: Texture2D = preload("res://assets/ui/icons/poison.png")

@onready var stats: HBoxContainer = %Stats

## Set by the run; ability charges are read from it
var turn: TurnController
var _character: Label
var _abilities: Dictionary[StringName, Label] = {}
var _hp: StatIcon
var _range: StatIcon
var _stun: InfoIcon
var _poison: InfoIcon
var _gold: StatIcon
var _bank: StatIcon
var max_pool_size: int = 9
var _equipment_box: HBoxContainer
## Equipment as last shown, and each item's uses label (item id -> Label, actives only)
var _equipment_shown: Array[String] = []
var _equipment_uses: Array = []
var _pool_box: HBoxContainer
var _pool_view: DieView
var _pool_label: Label
## The pool as last shown, to rebuild the die when it changes
var _pool_shown: Array[String] = []


func _ready() -> void:
	_character = Label.new()
	_character.add_theme_font_size_override("font_size", 24)
	stats.add_child(_character)
	_hp = _add(HEART, Color(1, 0.35, 0.35))
	_range = _add(BOW, Color(0.95, 0.85, 0.6))
	_range.tooltip_text = "Attack range"
	_stun = _status(STUN, Color(1.0, 0.75, 0.3), "Stunned", HelpText.PLAYER_STUNNED)
	_poison = _status(POISON, Color(0.55, 1.0, 0.45), "Poisoned", HelpText.PLAYER_POISONED)
	_gold = _add(COIN, Color(1, 0.82, 0.3))
	_bank = _add(BANK, Color(0.75, 0.8, 0.9))
	_equipment_box = HBoxContainer.new()
	_equipment_box.add_theme_constant_override("separation", 10)
	_equipment_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats.add_child(_equipment_box)
	_pool_box = HBoxContainer.new()
	_pool_box.add_theme_constant_override("separation", 4)
	_pool_box.tooltip_text = "Your dice"
	_pool_box.mouse_filter = Control.MOUSE_FILTER_PASS
	stats.add_child(_pool_box)
	_pool_label = Label.new()
	_pool_label.add_theme_font_size_override("font_size", 24)
	_pool_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_pool_label.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed("select"):
			pool_pressed.emit())


func _process(_delta: float) -> void:
	var run := SaveManager.run_data
	var low := run.health <= run.max_health / 3
	_hp.set_value("%d / %d" % [run.health, run.max_health], Color(1, 0.4, 0.35) if low else Color.WHITE)
	_gold.set_value(str(run.gold))
	var bank := SaveManager.progression_data.gold_in_bank
	_bank.set_value(str(bank))
	_bank.modulate.a = 1.0 if bank > 0 else 0.35
	_update_abilities()
	_update_equipment()
	_update_pool()
	# Range only shows beyond melee
	var has_player := turn != null and turn.player != null and is_instance_valid(turn.player)
	_range.visible = has_player and turn.player.attack_range > 1
	if _range.visible:
		_range.set_value(str(turn.player.attack_range))
	var poisoned := turn != null and turn.player != null and is_instance_valid(turn.player) and turn.player.poisoned
	var stunned := turn != null and turn.player != null and is_instance_valid(turn.player) and turn.player.stunned
	_stun.visible = stunned
	_poison.visible = poisoned


## One icon per equipped item (rarity colour, tooltip explains it); actives show uses left, as planned.
func _update_equipment() -> void:
	var run := SaveManager.run_data
	if run.equipment != _equipment_shown:
		_equipment_shown = run.equipment.duplicate()
		_equipment_uses.clear()
		for child in _equipment_box.get_children():
			child.queue_free()
		for item in run.equipped():
			var box := HBoxContainer.new()
			box.add_theme_constant_override("separation", 2)
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var icon := InfoIcon.new()
			icon.texture = item.get_icon()
			icon.modulate = Rarity.COLORS[item.rarity]
			icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.custom_minimum_size = Vector2(34, 34)
			icon.set_info("%s  ·  %s" % [item.display_name, item.kind()], item.info_rows())
			box.add_child(icon)
			for ability in item.abilities:
				if ability.active:
					var label := Label.new()
					label.add_theme_font_size_override("font_size", 16)
					label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45))
					box.add_child(label)
					_equipment_uses.append([ability, label])
			_equipment_box.add_child(box)
	if turn == null or turn.player == null:
		return
	var uses := turn.uses_preview()
	var total := turn.new_uses()
	for entry in _equipment_uses:
		var left: int = uses.get(entry[0].id, total.get(entry[0].id, 0))
		entry[1].text = "%d/%d" % [left, total.get(entry[0].id, 0)]
		entry[1].modulate.a = 1.0 if left > 0 else 0.35


## Rebuilds the pool die when the pool changes.
func _update_pool() -> void:
	var dice := SaveManager.run_data.dice
	_pool_label.text = "%d / %d" % [dice.size(), max_pool_size]
	if dice == _pool_shown:
		return
	_pool_shown = dice.duplicate()
	if _pool_view:
		_pool_view.queue_free()
		_pool_view = null
	if _pool_label.get_parent():
		_pool_box.remove_child(_pool_label)
	if dice.size() > 0:
		_pool_view = DieView.create(DicePoolView.sorted_types(dice)[0], 40.0)
		_pool_view.inspect_on_click = false
		_pool_view.clicked.connect(pool_pressed.emit)
		_pool_box.add_child(_pool_view)
	_pool_box.add_child(_pool_label)


## Character name, then each ability; the active shows its uses left this level (as planned while planning).
func _update_abilities() -> void:
	if turn == null or turn.player == null or turn.player.character == null:
		return
	var character := turn.player.character
	_character.text = character.display_name
	var uses := turn.uses_preview()
	for ability in character.abilities:
		if not _abilities.has(ability.id):
			var label := Label.new()
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.45) if ability.active else Color(0.8, 0.85, 0.95))
			label.tooltip_text = ability.description
			label.mouse_filter = Control.MOUSE_FILTER_PASS
			stats.add_child(label)
			stats.move_child(label, _character.get_index() + _abilities.size() + 1)
			_abilities[ability.id] = label
		var label := _abilities[ability.id]
		if ability.active:
			var left: int = uses.get(ability.id, 0)
			label.text = "%s %d/%d" % [ability.display_name, left, ability.uses_per_level]
			label.modulate.a = 1.0 if left > 0 else 0.35
		else:
			label.text = ability.display_name


## Status icon shown next to HP while the player has that status; hovering explains it.
func _status(texture: Texture2D, color: Color, title: String, explanation: String) -> InfoIcon:
	var icon := InfoIcon.new()
	icon.texture = texture
	icon.modulate = color
	var rows: Array[Dictionary] = [InfoPanel.row(texture, color, explanation)]
	icon.set_info(title, rows)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(32, 32)
	icon.visible = false
	stats.add_child(icon)
	return icon


func _add(texture: Texture2D, color: Color) -> StatIcon:
	var stat := StatIcon.create(texture, color, 24, 30)
	stats.add_child(stat)
	return stat
