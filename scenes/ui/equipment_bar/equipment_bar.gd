class_name EquipmentBar
extends CanvasLayer

## The equipped items as a column of round buttons on the side of the screen away from the turn plan, standing on the
## dice row's edge-most button (the character's first ability on the left, enemies go first on the right). Each shows
## the item's slot icon in its rarity colour; actives are pressed like ability buttons, passives only explain
## themselves. The turn controller fills it with [method set_items] every refresh; [signal equipment_changed] asks for
## one when the equipped items change (loot, shops).

signal pressed(ability: Ability)
signal equipment_changed

const MARGIN: float = 28.0
const GAP: float = 14.0

## Height of the dice row as a fraction of the screen (DiceTray.row_screen_y)
var row_y: float = 0.91

var _box: VBoxContainer
var _buttons: Array[CircleButton] = []
## The active each button uses (null for passives), by button
var _abilities: Array[Ability] = []
## Equipment as last seen, to notice changes
var _equipment_shown: Array[String] = []


func _ready() -> void:
	UITheme.watch(self)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", int(GAP))
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_box.resized.connect(_place)
	get_viewport().size_changed.connect(_place)
	SaveManager.settings_data.changed.connect(_place)
	_equipment_shown = SaveManager.run_data.equipment.duplicate()
	hide_bar()


func _exit_tree() -> void:
	if SaveManager.settings_data.changed.is_connected(_place):
		SaveManager.settings_data.changed.disconnect(_place)


func _process(_delta: float) -> void:
	if SaveManager.run_data.equipment != _equipment_shown:
		_equipment_shown = SaveManager.run_data.equipment.duplicate()
		equipment_changed.emit()


## One button per entry, top to bottom. Each entry: { ability (the item's active, or null), icon, icon_color, title,
## rows, enabled, highlighted, pulse }, plus the optional keys of [method CircleButton.apply].
func set_items(entries: Array[Dictionary]) -> void:
	while _buttons.size() > entries.size():
		_buttons.pop_back().queue_free()
		_abilities.pop_back()
	while _buttons.size() < entries.size():
		var button := CircleButton.create(entries[_buttons.size()].icon)
		var index := _buttons.size()
		button.pressed.connect(func():
			if _abilities[index]:
				pressed.emit(_abilities[index]))
		_box.add_child(button)
		button.set_progress(entries[index].get("progress", 1.0), false)
		_buttons.append(button)
		_abilities.append(null)
	for i in entries.size():
		_abilities[i] = entries[i].ability
		_buttons[i].apply(entries[i])
	_place()


func show_bar() -> void:
	if visible:
		return
	visible = true
	_place()
	_box.pivot_offset_ratio = Vector2(0.5, 1.0)
	_box.scale = Vector2.ONE * 0.6
	_box.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_box, "scale", Vector2.ONE, Anim.t(0.35)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_box, "modulate:a", 1.0, Anim.t(0.15))


func hide_bar() -> void:
	visible = false


## The edge away from the turn plan, bottom just above the dice row's buttons.
func _place() -> void:
	var screen := get_viewport().get_visible_rect().size
	_box.size = _box.get_combined_minimum_size()
	var left := SaveManager.settings_data.turn_plan_side == SettingsData.SIDE_RIGHT
	var x := MARGIN if left else screen.x - MARGIN - CircleButton.DIAMETER
	var bottom := screen.y * row_y - CircleButton.DIAMETER / 2.0 - GAP
	_box.position = Vector2(x, bottom - _box.size.y)
