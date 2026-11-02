class_name Backdrop
extends Node3D

## Falling streaks and the occasional small die shooting past in the void behind the board. A child of the run's
## camera: everything lies on a plane facing the camera far beyond the board (so the board always hides it) and is
## placed in screen units, so sizes and speeds stay the same whatever the camera distance.
## Screen units: y runs from -1 (bottom edge) to 1 (top edge), x from -aspect to aspect.

const STREAK_SHADER: Shader = preload("res://shaders/streak.gdshader")
const DIE_SCENE: PackedScene = preload("res://scenes/dice/die_3d.tscn")
## How far past the screen edges things start and end
const EDGE: float = 0.1

## Plane distance as a multiple of the camera rig's distance (the board sits at about 1×)
@export var depth_factor: float = 4.0
@export var max_streaks: int = 5
## Seconds between new streaks (min, max)
@export var streak_interval: Vector2 = Vector2(0.5, 1.8)
## Share of streaks that are fast
@export_range(0.0, 1.0) var fast_chance: float = 0.35
## Speeds in screen units per second (min, max)
@export var slow_speed: Vector2 = Vector2(0.12, 0.3)
@export var fast_speed: Vector2 = Vector2(1.4, 2.4)
## Fall direction: degrees off straight down, and the random spread either side
@export var slant: float = 12.0
@export var slant_spread: float = 6.0
@export var streak_color: Color = Color(0.55, 0.65, 1.0, 0.55)
@export var max_dice: int = 1
## Seconds between dice (min, max)
@export var die_interval: Vector2 = Vector2(5.0, 12.0)
@export var die_speed: Vector2 = Vector2(0.6, 1.0)
## Die size in screen units (board dice in the row are roughly 0.18)
@export var die_size: float = 0.04

var rig: CameraRig
## Each: { node, head (Vector2), dir, speed, length, width } - plus die and spin for dice
var _streaks: Array[Dictionary] = []
var _dice: Array[Dictionary] = []
var _streak_timer: float = 0.0
var _die_timer: float = 0.0
var _rng := RandomNumberGenerator.new()
## Rarity -> die types of that rarity
var _types: Dictionary[int, Array] = {}
var _quad := QuadMesh.new()


func _ready() -> void:
	_rng.randomize()
	for category in ["dice", "dice_debug"]:
		for type: DieType in Database.get_all(category):
			if not _types.has(type.rarity):
				_types[type.rarity] = []
			_types[type.rarity].append(type)
	# A few slow streaks already falling, so the void isn't empty at the start
	for i in 2:
		_spawn_streak(_rng.randf_range(-0.6, 0.9), false)
	_die_timer = _rng.randf_range(1.5, die_interval.x)


func _process(delta: float) -> void:
	var camera := get_parent() as Camera3D
	if camera == null or rig == null:
		return
	var depth := rig.distance * depth_factor
	var half_height := depth * tan(deg_to_rad(camera.fov) / 2.0)

	_streak_timer -= delta
	if _streak_timer <= 0.0:
		_streak_timer = _rng.randf_range(streak_interval.x, streak_interval.y)
		if _streaks.size() < max_streaks:
			_spawn_streak(1.0 + EDGE, _rng.randf() < fast_chance)
	_die_timer -= delta
	if _die_timer <= 0.0:
		_die_timer = _rng.randf_range(die_interval.x, die_interval.y)
		if _dice.size() < max_dice and not _types.is_empty():
			_spawn_die()

	for streak in _streaks.duplicate():
		if not _move(streak, delta, depth, half_height):
			_streaks.erase(streak)
	for die in _dice.duplicate():
		if _move(die, delta, depth, half_height):
			var body: Die3D = die.die
			body.position = Vector3(die.head.x, die.head.y, 0.0) * half_height + Vector3(0, 0, -depth)
			body.visual.scale = Vector3.ONE * die_size * half_height
			body.rotate(die.axis, die.spin * delta)
		else:
			die.die.queue_free()
			_dice.erase(die)


## Advances [entry] and places its streak. Returns false (and frees the streak) once it's left the screen.
func _move(entry: Dictionary, delta: float, depth: float, half_height: float) -> bool:
	entry.head += entry.dir * entry.speed * delta
	var tail: Vector2 = entry.head - entry.dir * entry.length
	var aspect := _aspect()
	if tail.y < -1.0 - EDGE or absf(tail.x) > aspect + 0.5:
		entry.node.queue_free()
		return false
	var node: MeshInstance3D = entry.node
	var centre: Vector2 = entry.head - entry.dir * entry.length / 2.0
	# The quad's bottom (UV.y = 1, the bright head) points along the direction of travel
	var basis := Basis(Vector3.BACK, atan2(entry.dir.x, -entry.dir.y)) * Basis.from_scale(Vector3(entry.width, entry.length, 1.0) * half_height)
	node.transform = Transform3D(basis, Vector3(centre.x, centre.y, 0.0) * half_height + Vector3(0, 0, -depth))
	return true


func _spawn_streak(y: float, fast: bool) -> void:
	var length := _rng.randf_range(0.35, 0.7) if fast else _rng.randf_range(0.08, 0.22)
	var color := streak_color
	color.a *= 1.0 if fast else 0.6
	_streaks.append({
		"node": _streak_node(color),
		"head": Vector2(_start_x(), y),
		"dir": _fall_direction(slant_spread),
		"speed": _rng.randf_range(fast_speed.x, fast_speed.y) if fast else _rng.randf_range(slow_speed.x, slow_speed.y),
		"length": length,
		"width": 0.006 if fast else 0.009,
	})


## A small die of a random rarity tumbling across with a trail in its rarity colour.
func _spawn_die() -> void:
	var rarities := _types.keys()
	var types: Array = _types[rarities[_rng.randi() % rarities.size()]]
	var type: DieType = types[_rng.randi() % types.size()]
	var design: DieDesign = Database.get_content("die_designs", SaveManager.progression_data.die_design)
	if design == null:
		design = Database.get_all("die_designs")[0]
	var die: Die3D = DIE_SCENE.instantiate()
	die.setup(-1, type, design)
	die.freeze = true
	die.collision_layer = 0
	die.collision_mask = 0
	die.input_ray_pickable = false
	add_child(die)
	# Lit by the board's sun (dice are normally on the tray's light layer), and no shadows
	for mesh: MeshInstance3D in die.find_children("*", "MeshInstance3D", true, false):
		mesh.layers = 1
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var color := Rarity.COLORS[type.rarity]
	color.a = 0.45
	_dice.append({
		"node": _streak_node(color),
		"die": die,
		"head": Vector2(_start_x(), 1.0 + EDGE + die_size),
		"dir": _fall_direction(slant_spread * 3.0),
		"speed": _rng.randf_range(die_speed.x, die_speed.y),
		"length": _rng.randf_range(0.35, 0.55),
		"width": die_size * 0.45,
		"axis": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized(),
		"spin": _rng.randf_range(3.0, 7.0),
	})


func _streak_node(color: Color) -> MeshInstance3D:
	var material := ShaderMaterial.new()
	material.shader = STREAK_SHADER
	material.set_shader_parameter("color", color)
	var node := MeshInstance3D.new()
	node.mesh = _quad
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)
	return node


## Start x, shifted against the slant so streaks cover the whole screen on their way down.
func _start_x() -> float:
	var aspect := _aspect()
	return _rng.randf_range(-aspect, aspect) - tan(deg_to_rad(slant)) * 1.0


func _fall_direction(spread: float) -> Vector2:
	var angle := deg_to_rad(slant + _rng.randf_range(-spread, spread))
	return Vector2(sin(angle), -cos(angle))


func _aspect() -> float:
	var size := get_viewport().get_visible_rect().size
	return size.x / size.y
