class_name DieView
extends Control

## A die in its own small 3D world, used wherever dice are shown outside the result row. Drag to turn it in place
## (a flick keeps it spinning for a moment); a click without dragging opens the [DieInspector] with all six faces,
## or only emits [signal clicked] when [member inspect_on_click] is off. Turns slowly on its own until dragged.
## Use: var view := DieView.create(type, 120.0)

signal clicked

const DIE_SCENE: PackedScene = preload("res://scenes/dice/die_3d.tscn")
const ENVIRONMENT: Environment = preload("res://assets/default_environment.tres")
## Mouse travel before a press counts as a drag rather than a click
const DRAG_THRESHOLD: float = 6.0
## Radians per pixel dragged
const DRAG_SPEED: float = 0.012
## How quickly a flick's spin dies down
const SPIN_DAMPING: float = 4.0
## Radians per second about the vertical while idle
const IDLE_SPEED: float = 0.45
const HOVER_SCALE: float = 1.08
## The die fills this share of the view at its widest
const CAMERA_DISTANCE: float = 3.7

var die_type: DieType
var die: Die3D
## Click opens the inspector (otherwise only [signal clicked] fires)
var inspect_on_click: bool = true
## Turns slowly until the player first drags it
var idle_spin: bool = true

var _viewport: SubViewport
var _pressed: bool = false
var _dragging: bool = false
var _press_position: Vector2
## Spin in radians per second: x about the vertical, y about the horizontal
var _spin: Vector2 = Vector2.ZERO
var _turn_tween: Tween


static func create(type: DieType, view_size: float, idle: bool = true) -> DieView:
	var view := DieView.new()
	view.die_type = type
	view.custom_minimum_size = Vector2.ONE * view_size
	view.idle_spin = idle
	return view


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.transparent_bg = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	var picture := TextureRect.new()
	picture.texture = _viewport.get_texture()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.set_anchors_preset(Control.PRESET_FULL_RECT)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	resized.connect(_fit_viewport)
	_fit_viewport()

	var environment: Environment = ENVIRONMENT.duplicate()
	environment.background_mode = Environment.BG_CLEAR_COLOR
	environment.ssao_enabled = false
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0, 0, CAMERA_DISTANCE)
	_viewport.add_child(camera)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-40, -30, 0)
	key.light_energy = 1.1
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20, 140, 0)
	fill.light_energy = 0.3
	_viewport.add_child(fill)

	var design: DieDesign = Database.get_content("die_designs", SaveManager.progression_data.die_design)
	if design == null:
		design = Database.get_all("die_designs")[0]
	die = DIE_SCENE.instantiate()
	die.setup(-1, die_type, design)
	die.freeze = true
	die.collision_layer = 0
	die.collision_mask = 0
	die.input_ray_pickable = false
	# Three-quarter view: top, front and right faces
	die.basis = Basis(Vector3.RIGHT, deg_to_rad(25)) * Basis(Vector3.UP, deg_to_rad(-30))
	_viewport.add_child(die)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))


## Square render target matching the view's size.
func _fit_viewport() -> void:
	var side := maxi(int(minf(size.x, size.y)), 16)
	_viewport.size = Vector2i(side, side)


func _process(delta: float) -> void:
	if not die or _dragging or (_turn_tween and _turn_tween.is_running()):
		return
	if _spin.length() > 0.01:
		_rotate(_spin * delta)
		_spin *= exp(-SPIN_DAMPING * delta)
	elif idle_spin:
		_rotate(Vector2(IDLE_SPEED * delta, 0.0))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		if event.pressed:
			_pressed = true
			_dragging = false
			_press_position = event.position
			_spin = Vector2.ZERO
		elif _pressed:
			_pressed = false
			if _dragging:
				_dragging = false
			else:
				_click()
	elif event is InputEventMouseMotion and _pressed:
		accept_event()
		if not _dragging and event.position.distance_to(_press_position) > DRAG_THRESHOLD:
			_dragging = true
			idle_spin = false
			if _turn_tween:
				_turn_tween.kill()
		if _dragging:
			var turn: Vector2 = event.relative * DRAG_SPEED
			_rotate(turn)
			# Keeps the last drag speed for the flick
			var delta := maxf(get_process_delta_time(), 0.001)
			_spin = _spin.lerp(turn / delta, 0.5)


func _click() -> void:
	clicked.emit()
	if inspect_on_click:
		DieInspector.open(self, die_type)


## Turns the die in screen space: [amount].x about the vertical, .y about the horizontal.
func _rotate(amount: Vector2) -> void:
	die.basis = (Basis(Vector3.UP, amount.x) * Basis(Vector3.RIGHT, amount.y) * die.basis).orthonormalized()


## Turns the die to show [face_index] head-on, artwork upright.
func show_face(face_index: int) -> void:
	idle_spin = false
	_spin = Vector2.ZERO
	var from := die.basis.get_rotation_quaternion()
	var to := Die3D.basis_facing(face_index, Basis.IDENTITY).get_rotation_quaternion()
	if _turn_tween:
		_turn_tween.kill()
	_turn_tween = create_tween()
	_turn_tween.tween_method(func(t: float): die.basis = Basis(from.slerp(to, t)), 0.0, 1.0, Anim.t(0.35)) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	die.pop()


## Grows from nothing while spinning fast, settling into the idle turn.
func spin_in() -> void:
	_spin = Vector2(22.0, 7.0)
	die.visual.scale = Vector3.ONE * 0.01
	create_tween().tween_property(die.visual, "scale", Vector3.ONE, Anim.t(0.7)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _set_hovered(hovered: bool) -> void:
	if die:
		create_tween().tween_property(die.visual, "scale", Vector3.ONE * (HOVER_SCALE if hovered else 1.0), Anim.t(0.12)) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
