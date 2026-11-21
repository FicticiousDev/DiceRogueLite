class_name AbilityBar
extends CanvasLayer

## The player's active abilities (character and items) as round buttons along the left edge of the screen, level with
## the dice row. The turn controller fills it with [method set_abilities] every refresh.

signal pressed(ability: Ability)

const MARGIN: float = 28.0
const GAP: float = 14.0

## Height of the dice row as a fraction of the screen (DiceTray.row_screen_y)
var row_y: float = 0.91

var _box: HBoxContainer
var _buttons: Dictionary[Ability, CircleButton] = {}


func _ready() -> void:
	UITheme.watch(self)
	_box = HBoxContainer.new()
	_box.add_theme_constant_override("separation", int(GAP))
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_box)
	_box.resized.connect(_place)
	get_viewport().size_changed.connect(_place)
	hide_bar()


## One button per entry, in order. Each entry: { ability, title, rows, badge, enabled, highlighted, pulse }.
func set_abilities(entries: Array[Dictionary]) -> void:
	var wanted: Array[Ability] = []
	for entry in entries:
		wanted.append(entry.ability)
	for ability in _buttons.keys():
		if not wanted.has(ability):
			_buttons[ability].queue_free()
			_buttons.erase(ability)
	for i in entries.size():
		var entry := entries[i]
		var button: CircleButton = _buttons.get(entry.ability)
		if button == null:
			button = CircleButton.create(entry.ability.get_icon())
			var ability: Ability = entry.ability
			button.pressed.connect(func(): pressed.emit(ability))
			_box.add_child(button)
			_buttons[ability] = button
		_box.move_child(button, i)
		button.set_info(entry.title, entry.rows)
		button.set_badge(entry.badge)
		button.disabled = not entry.enabled
		button.set_highlighted(entry.highlighted, entry.pulse)
	_place()


func show_bar() -> void:
	if visible:
		return
	visible = true
	_box.pivot_offset_ratio = Vector2(0.0, 0.5)
	_box.scale = Vector2.ONE * 0.6
	_box.modulate.a = 0.0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_box, "scale", Vector2.ONE, Anim.t(0.35)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_box, "modulate:a", 1.0, Anim.t(0.15))


func hide_bar() -> void:
	visible = false


## Left edge of the screen, centred on the dice row.
func _place() -> void:
	var screen := get_viewport().get_visible_rect().size
	_box.size = _box.get_combined_minimum_size()
	_box.position = Vector2(MARGIN, screen.y * row_y - _box.size.y / 2.0)
