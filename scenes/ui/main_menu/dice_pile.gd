class_name DicePile
extends Node3D

## A loose pyramid of random dice in the player's chosen design and finishes, turning slowly about its origin (the centre of
## its base). The dice are placed by hand, not simulated, and taken out of the physics world so they turn smoothly with
## this node.
## Use: pile.place(base_position) builds it; pile.refresh() whenever the player may have changed their dice.

const DIE_SCENE: PackedScene = preload("res://scenes/dice/die_3d.tscn")
## Die centres in die units: a 2 x 2 base, one on top, one lying beside the base
const LAYOUT: Array[Vector3] = [
	Vector3(-0.58, 0.5, -0.58), Vector3(0.58, 0.5, -0.58), Vector3(-0.58, 0.5, 0.58), Vector3(0.58, 0.5, 0.58),
	Vector3(0.04, 1.5, -0.02),
	Vector3(0.3, 0.5, 1.72),
]
## Most a die is turned off square, in radians
const YAW_JITTER: float = 0.2
## Most a die is shifted off its spot, in die units
const POSITION_JITTER: float = 0.05

## Side of a die in world units
@export var die_size: float = 0.55
## Turn speed in radians per second
@export var spin_speed: float = 0.25

var _dice: Array[Die3D] = []
## The look the current pile was built with
var _look: String = ""


func _process(delta: float) -> void:
	rotate_y(spin_speed * delta)


## Height of the pile's middle above its base, in world units.
func centre_height() -> float:
	return die_size


## Moves the pile's base to [param at], building it the first time.
func place(at: Vector3) -> void:
	position = at
	if _look == "":
		build()


## Rebuilds the pile if the player's dice look has changed since it was built.
func refresh() -> void:
	if _look_key() != _look:
		build()


## Builds a new pile, replacing the current one.
func build() -> void:
	_look = _look_key()
	for die in _dice:
		die.queue_free()
	_dice.clear()
	var design := _player_design()
	var types := _types()
	for i in LAYOUT.size():
		var die: Die3D = DIE_SCENE.instantiate()
		die.setup(i, types.pick_random(), design, die_size)
		die.freeze = true
		# Out of the physics world, so the die follows this node's rotation every frame instead of every physics tick
		die.process_mode = Node.PROCESS_MODE_DISABLED
		var jitter := Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * POSITION_JITTER
		die.position = (LAYOUT[i] + jitter) * die_size
		# A random face up, then a little off square
		var square := Vector3(randi() % 4, randi() % 4, randi() % 4) * PI * 0.5
		die.basis = Basis(Vector3.UP, randf_range(-YAW_JITTER, YAW_JITTER)) * Basis.from_euler(square)
		add_child(die)
		_dice.append(die)


## Dice the player has unlocked, or every die if none are.
func _types() -> Array:
	var all := Database.get_all("dice")
	var unlocked := all.filter(func(t: DieType): return SaveManager.progression_data.is_die_unlocked(t))
	return unlocked if not unlocked.is_empty() else all


func _player_design() -> DieDesign:
	var design: DieDesign = Database.get_content("die_designs", SaveManager.progression_data.die_design)
	return design if design else Database.get_all("die_designs")[0]


func _look_key() -> String:
	var progression := SaveManager.progression_data
	return "%s/%s/%s" % [progression.die_design, progression.die_finish, progression.die_trim_finish]
