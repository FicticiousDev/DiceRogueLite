class_name SplashScreen
extends CanvasLayer

## Launch splash, on a black void. A white die falls in from the top right at an angle, hits the (invisible) ground right of
## centre and makes one big bounce: a single ballistic arc across the screen and off the left edge. The die slows as it
## crosses the centre, where the engine logo faces the camera. It comes back spinning fast on one corner, the spin dying
## away so it wobbles and loses balance, then topples onto the studio logo face. The camera then tilts up over the die to
## look straight down at its top face, which carries the game name. All three are embossed in the die.
## Use: await splash.play() - returns at once if skipped (settings) or already played this launch. The screen stays up
## afterwards so the loading screen can fade in over it (LoadingScreen.run).
##
## Motion is a simple simulation in "fall time" units (the time the die takes to fall from its start): gravity is whatever
## makes the drop take 1 unit, the horizontal speed is constant in flight, the bounce keeps [member restitution] of the
## impact speed, and the die's spin is constant in flight (changing only at the impact). The slowdown at the centre is a
## time remap, so the path stays the true parabola and the roll slows with it.

const DIE_SCENE: PackedScene = preload("res://scenes/dice/die_3d.tscn")
const ENVIRONMENT: Environment = preload("res://assets/default_environment.tres")
const ENGINE_LOGO: Texture2D = preload("res://assets/splash/engine.png")
const STUDIO_LOGO: Texture2D = preload("res://assets/splash/studio.png")
const GAME_NAME: Texture2D = preload("res://assets/splash/game.png")

## Die look: a plain die, so the embossing is what you see
const SAMPLE_DIE: StringName = &"all_rounder"
const DESIGN: StringName = &"classic"
const FINISH: StringName = &"plastic"
## A little darker than the rare tier's blue
const BODY_COLOR: Color = Color(0.30, 0.46, 0.78)
## Face indices (see DieType): top, right, front
const FACE_GAME: int = 0
const FACE_ENGINE: int = 1
const FACE_STUDIO: int = 2

## Emboss textures (4x the pixels of the in-game faces, so logos are sharp even when the die fills the screen)
const ART_SIZE: int = 1024
## Share of the face the logo's longest side fills
const ART_FILL: float = 0.94
## Relief strength (scaled with ART_SIZE) and bevel softness (the height map is blurred by shrinking it by this much)
const BUMP_SCALE: float = 12.0
const BLUR_DIVISOR: int = 5
## Logos on black have no alpha: brightness above LUMA_FLOOR becomes the shape, fully solid LUMA_GAIN steps above it
const LUMA_FLOOR: float = 0.03
const LUMA_GAIN: float = 16.0
## The logo's inside is found on a grid this size (dark parts inside the logo, like outlines, stay solid)
const MASK_SIZE: int = 256
const SCAN_SIZE: int = 128

const FLOOR_Y: float = -0.5
const CAMERA_FOV: float = 35.0
## Width (in fall times) of the slowdown around the centre crossing
const SLOW_WIDTH: float = 0.17
## Share of the bounce roll the die already has while falling
const FALL_SPIN_SHARE: float = 0.3
## Turns the lean's direction makes about the vertical while the spinning die loses balance
const WOBBLE_TURNS: float = 1.5
## How sharply the corner spin slows (higher: fast at the start, little left towards the end)
const SPIN_DECAY: float = 3.0
## Share of the spin's speed that never dies away: the die is still turning slowly as it falls over
const SPIN_FLOOR: float = 0.15
## How late the die tips over (higher: a longer wobble on the corner, then a quicker fall)
const LEAN_POWER: float = 3.5
## Distance from the screen edge at which the die counts as off screen (its half diagonal and a bit)
const OFFSCREEN_MARGIN: float = 0.95
## Camera distance to the top face at the end (the loading screen lines its game name up with the die's)
const TOP_DISTANCE: float = 1.8

@export_group("Timing")
## Fall from above, then the one bounce right to left, slowest in the middle
## (for the whole fall: the part before the die is on screen is skipped, at the same speed)
@export var pass_time: float = 2.9
## Back from the left, spinning, to the landing
@export var return_time: float = 2.4
@export var settle_time: float = 0.5
@export var tilt_time: float = 1.5
## On the game name before the loading screen takes over
@export var hold_time: float = 1.0

@export_group("Die")
## How far the middle of the pass is slowed (0-1; 1 would stop the die)
@export_range(0.0, 0.95) var slowdown: float = 0.8
## Camera distance to the die's plane
@export var camera_distance: float = 4.4
## Camera elevation above the horizontal at the start (degrees)
@export var camera_elevation: float = 8.0

@export_group("Bounce")
## Where the die hits the invisible ground: its centre this far above the bottom edge of the screen, in half screen heights
@export_range(0.0, 1.0) var ground_level: float = 0.2
## Where the slowdown happens, as a height above the screen centre (in half screen heights). It sits two thirds of the way up
## the rising arc, so this sets how high the bounce goes; the fall and the entry angle follow from it
@export_range(-0.5, 0.8) var slowdown_level: float = 0.3
## Share of the impact speed kept going up
@export_range(0.3, 0.9) var restitution: float = 0.75
## Where the die lands, as a share of the half screen width right of the centre
@export_range(0.2, 0.95) var land_position: float = 0.7
## Roll through the bounce in turns per fall time (positive: tumbling the way it travels)
@export var bounce_roll_turns: float = 0.9
## Corner spin speed at the start of the return, radians per second
@export var corner_spin_rate: float = 30.0

var _viewport: SubViewport
var _camera: Camera3D
var _mover: Node3D
var _die: Die3D
var _face_height: float
var _face_basis: Basis
var _roll_axis: Vector3 = Vector3(0.12, 0.1, 1.0).normalized()
var _corner_basis: Basis = Basis(Quaternion(Vector3(1, 1, 1).normalized(), Vector3.UP))
## Pass: landing x, and the bounce's time (after landing) at the centre crossing and at leaving the screen
var _land_x: float
var _land_y: float
var _drop: float
var _run: float
var _edge_x: float
var _s_centre: float
var _s_end: float
var _roll_rate: float
var _bounced: bool
## Cumulative remapped time at evenly spaced fall times, to turn the pass's progress into fall time
var _clock: PackedFloat32Array = PackedFloat32Array()
var _spin_total: float
var _tau_start: float
var _pass_seconds: float
var _heading_total: float
var _lean_final: float
var _playing: bool
var _skipped: bool
var _active_tween: Tween

## Set once played so returning to the main menu doesn't replay it
static var has_played: bool = false


func play() -> void:
	if SaveManager.settings_data.skip_splash or has_played:
		return
	has_played = true
	var art := await _build_art()
	if not _build_stage(art):
		return
	_playing = true
	await _tween_through(_pass_step, _pass_seconds)
	await _tween_through(_return_step, return_time)
	if not _skipped:
		_impact()
	await _wait(settle_time)
	await _tween_through(_tilt_step, tilt_time, Tween.TRANS_CUBIC, Tween.EASE_IN_OUT)
	await _wait(hold_time)
	_playing = false


## Click, space or escape skips the rest of the splash (the loading screen follows at once).
func _input(event: InputEvent) -> void:
	if not _playing or _skipped:
		return
	var pressed := false
	if event is InputEventMouseButton:
		pressed = event.pressed
	elif event is InputEventKey:
		pressed = event.pressed and not event.echo and (event.keycode == KEY_SPACE or event.keycode == KEY_ESCAPE)
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	_skipped = true
	_playing = false
	# Finishing the running tween ends the current wait; every later step then returns at once
	if _active_tween and _active_tween.is_valid():
		_active_tween.custom_step(1000000.0)


# ===========================================================================================================================================
# Sequence
# ===========================================================================================================================================


## Runs [step] from 0 to 1 over [seconds] (linear unless a curve is given).
func _tween_through(step: Callable, seconds: float, trans: Tween.TransitionType = Tween.TRANS_LINEAR,
		ease_type: Tween.EaseType = Tween.EASE_IN_OUT) -> void:
	if _skipped:
		return
	step.call(0.0)
	_active_tween = create_tween()
	_active_tween.tween_method(step, 0.0, 1.0, Anim.t(seconds)).set_trans(trans).set_ease(ease_type)
	await _active_tween.finished


func _wait(seconds: float) -> void:
	if _skipped:
		return
	_active_tween = create_tween()
	_active_tween.tween_interval(Anim.t(seconds))
	await _active_tween.finished


## Works out the pass from the screen size: where the die lands, when it crosses the centre and leaves, and the clock that
## slows it around the centre.
func _plan_pass() -> void:
	var aspect := get_viewport().get_visible_rect().size.aspect()
	var half_height := tan(deg_to_rad(CAMERA_FOV) * 0.5) * camera_distance
	var half_width := half_height * aspect
	_land_x = half_width * land_position
	_edge_x = half_width + OFFSCREEN_MARGIN
	# The ground is near the bottom of the screen; the slowdown is at two thirds of the arc's height, on the way up
	_land_y = -half_height * (1.0 - ground_level)
	var rise := (half_height * slowdown_level - _land_y) * 1.5
	# Apex height = restitution^2 x drop, so this is the drop that gives that rise
	_drop = rise / (restitution * restitution)
	# Time after landing when the die is two thirds of the way up to the apex: y = d(2es - s^2) = 2/3 d e^2
	_s_centre = restitution * (1.0 - sqrt(1.0 / 3.0))
	# Horizontal speed that puts the die at x = 0 at that moment
	_run = _land_x / _s_centre
	# Leaves the screen on its way down at the latest at the second landing
	_s_end = minf((_land_x + _edge_x) / _run, 2.0 * restitution * 0.98)
	_roll_rate = TAU * bounce_roll_turns
	var tau_centre := 1.0 + _s_centre
	var tau_end := 1.0 + _s_end
	# Starts when the die first comes into view, from the top or the right, rather than somewhere above the screen
	var tau_x := 1.0 - (half_width + OFFSCREEN_MARGIN - _land_x) / _run
	var above := half_height + OFFSCREEN_MARGIN - _land_y
	var tau_y := sqrt(maxf(1.0 - above / _drop, 0.0))
	_tau_start = clampf(maxf(tau_x, tau_y), 0.0, 0.95)
	var full_total := _build_clock(0.0, tau_centre, tau_end)
	var total := _build_clock(_tau_start, tau_centre, tau_end)
	_pass_seconds = pass_time * total / full_total


## Fills the clock (cumulative remapped time) from fall time [from] to [tau_end], slowest at [tau_centre]. Returns its total.
func _build_clock(from: float, tau_centre: float, tau_end: float) -> float:
	var steps := 800
	_clock.resize(steps + 1)
	_clock[0] = 0.0
	for i in steps:
		var tau := from + (i + 0.5) / steps * (tau_end - from)
		var rate := 1.0 - slowdown * exp(-pow((tau - tau_centre) / SLOW_WIDTH, 2.0))
		_clock[i + 1] = _clock[i] + (tau_end - from) / steps / rate
	return _clock[steps]


## Fall time at progress [u] (0-1) of the pass.
func _fall_time(u: float) -> float:
	var steps := _clock.size() - 1
	var target := u * _clock[steps]
	var i := clampi(_clock.bsearch(target) - 1, 0, steps - 1)
	var span := _clock[i + 1] - _clock[i]
	var f := clampf((target - _clock[i]) / span, 0.0, 1.0) if span > 0.0 else 0.0
	return _tau_start + (i + f) / steps * (1.0 + _s_end - _tau_start)


## The pass: a fall from the top right, then one parabola across the screen. The engine face points at the camera at the
## centre crossing, where the clock runs slowest.
func _pass_step(u: float) -> void:
	var tau := _fall_time(u)
	var x: float
	var y: float
	var angle: float
	if tau < 1.0:
		# Falling at constant horizontal speed, turning slowly
		x = _land_x + _run * (1.0 - tau)
		y = _land_y + _drop * (1.0 - tau * tau)
		angle = -_roll_rate * _s_centre + _roll_rate * FALL_SPIN_SHARE * (tau - 1.0)
	else:
		if not _bounced:
			_bounced = true
			_impact()
		var s := tau - 1.0
		# Same horizontal speed, upward speed = restitution x the impact speed (2 x drop per fall time)
		x = _land_x - _run * s
		y = _land_y + _drop * (2.0 * restitution * s - s * s)
		# Spin is constant through the arc (it was set at the impact), so the roll is steady
		angle = _roll_rate * (s - _s_centre)
	_place(x, y, Basis(_roll_axis, angle) * _face_basis, false)


## From the left edge to the middle on one corner, already at full spin. The spin dies away to a slow turn while the die
## leans further and further over, its lean swinging round the way it spins, until it falls onto the studio face: studio
## logo to the front, game name on top. One continuous motion: it never stops, reverses or hops.
func _return_step(k: float) -> void:
	var x := lerpf(-_edge_x, 0.0, 1.0 - pow(1.0 - k, 2.0))
	_place(x, 0.0, _return_basis(k))


## Orientation [k] (0-1) through the return: spinning about the corner it stands on, leaning over and swinging its lean
## round. At k = 1 it is exactly the flat landing orientation.
func _return_basis(k: float) -> Basis:
	var spin := _spin_total * (SPIN_FLOOR * k + (1.0 - SPIN_FLOOR) * (1.0 - pow(1.0 - k, SPIN_DECAY)))
	var lean := _lean_final * pow(k, LEAN_POWER)
	# Swings round faster as it tips
	var heading := _heading_total * (0.25 * k + 0.75 * k * k)
	return Basis(Vector3.UP, heading) * Basis(Vector3.RIGHT, lean) * Basis(Vector3.UP, spin) * _corner_basis


## Works out the angles at the end of the return that make the die land flat as the studio-face landing orientation, and
## picks whole extra turns so everything keeps turning the same way: heading and spin both increase all the way.
func _plan_return() -> void:
	# Lean that takes the die from standing on a corner to a face flat on the ground
	_lean_final = acos(1.0 / sqrt(3.0))
	# Landing orientation = heading * lean * spin * corner. The lean tips the standing diagonal onto its landing direction
	# when the heading is 45 degrees; the spin is then whatever completes it
	var heading_end := PI / 4.0
	var rest := Basis(Vector3.RIGHT, -_lean_final) * Basis(Vector3.UP, -heading_end) * _corner_basis.inverse()
	var spin_end := atan2(-rest.x.z, rest.x.x)
	_heading_total = heading_end + TAU * roundf(WOBBLE_TURNS - heading_end / TAU)
	# Whole turns added until the spin starts at about corner_spin_rate
	var wanted := corner_spin_rate * return_time / (SPIN_FLOOR + (1.0 - SPIN_FLOOR) * SPIN_DECAY)
	_spin_total = spin_end + TAU * roundf((wanted - spin_end) / TAU)


## Camera swings up over the die until it looks straight down at the centre of the top face.
func _tilt_step(t: float) -> void:
	var pivot := Vector3(0.0, _face_height * t, 0.0)
	_aim_camera(lerpf(camera_elevation, 90.0, t), pivot, lerpf(camera_distance, TOP_DISTANCE, t))


## Puts the die at [x] with [basis]. In the air [y] is the height of its centre in the world; grounded it is the height above
## resting on the floor at the middle of the screen.
func _place(x: float, y: float, basis: Basis, grounded: bool = true) -> void:
	_mover.basis = basis
	_mover.position = Vector3(x, (FLOOR_Y + _support(basis) + y) if grounded else y, 0.0)
	_aim_camera(camera_elevation, Vector3.ZERO, camera_distance)


## Height of the cube's centre above its lowest point at [basis].
func _support(basis: Basis) -> float:
	return 0.5 * (absf(basis.x.y) + absf(basis.y.y) + absf(basis.z.y))


## Orbits the camera around [pivot]: [elevation] degrees above the horizontal, [distance] away, looking at it. At 90 it
## looks straight down with the top of the picture towards -Z, which is the upright direction on the die's top face.
func _aim_camera(elevation: float, pivot: Vector3, distance: float) -> void:
	var tilt := Basis(Vector3.RIGHT, -deg_to_rad(elevation))
	_camera.basis = tilt
	_camera.position = pivot + tilt * Vector3(0.0, 0.0, distance)


## Landing thud: the die squashes and the camera jolts.
func _impact() -> void:
	var squash := create_tween()
	squash.tween_property(_die.visual, "scale", Vector3(1.12, 0.84, 1.12), Anim.t(0.05))
	squash.tween_property(_die.visual, "scale", Vector3.ONE, Anim.t(0.4)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	if SaveManager.settings_data.screen_shake:
		var jolt := create_tween()
		jolt.tween_method(func(amount: float): _camera.v_offset = randf_range(-1.0, 1.0) * amount * 0.12, 1.0, 0.0, Anim.t(0.35))
		jolt.tween_callback(func(): _camera.v_offset = 0.0)


# ===========================================================================================================================================
# Stage
# ===========================================================================================================================================


## Builds the 3D view, die and lights. False if the content the die needs isn't there (the splash is then skipped).
func _build_stage(art: Array) -> bool:
	var type: DieType = Database.get_content("dice", SAMPLE_DIE)
	var design: DieDesign = Database.get_content("die_designs", DESIGN)
	if design == null and Database.get_all("die_designs").size() > 0:
		design = Database.get_all("die_designs")[0]
	if type == null or design == null:
		push_warning("SplashScreen: no die or design found, skipping")
		return false

	var container := SubViewportContainer.new()
	container.stretch = true
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(container)
	_viewport = SubViewport.new()
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	container.add_child(_viewport)

	var environment: Environment = ENVIRONMENT.duplicate()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color.BLACK
	environment.ssao_enabled = false
	environment.ambient_light_energy = 0.35
	var world := WorldEnvironment.new()
	world.environment = environment
	_viewport.add_child(world)

	_camera = Camera3D.new()
	_camera.fov = CAMERA_FOV
	_viewport.add_child(_camera)
	_camera.make_current()

	# Light from the front left and above: low enough to show the relief on both the front and top faces
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-50, -35, 0)
	key.light_energy = 0.95
	_viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(20, 140, 0)
	fill.light_energy = 0.2
	_viewport.add_child(fill)

	_mover = Node3D.new()
	_viewport.add_child(_mover)
	_die = DIE_SCENE.instantiate()
	_die.setup(-1, type, design)
	# Null if missing: the die then falls back to the player's finish
	_die.finish = Database.get_content("die_finishes", FINISH)
	_die.freeze = true
	_die.collision_layer = 0
	_die.collision_mask = 0
	_mover.add_child(_die)
	_paint_body()
	_die.set_face_art(FACE_ENGINE, art[0][0], art[0][1], 1.0, 1.0)
	_die.set_face_art(FACE_STUDIO, art[1][0], art[1][1], 1.0, 1.0)
	_die.set_face_art(FACE_GAME, art[2][0], art[2][1], 1.0, 1.0)

	_face_height = design.face_offset
	_aim_camera(camera_elevation, Vector3.ZERO, camera_distance)
	_face_basis = Die3D.basis_facing(FACE_ENGINE, _camera.basis)
	_bounced = false
	_plan_pass()
	_plan_return()
	# Off screen to the upper right until the sequence starts
	_pass_step(0.0)
	_bounced = false
	return true


## The splash die is blue whatever its rarity.
func _paint_body() -> void:
	for i in _die.body.mesh.get_surface_count():
		var material := _die.body.get_surface_override_material(i) as ShaderMaterial
		if material:
			material.set_shader_parameter("body_color", BODY_COLOR)
	for face in _die.faces_root.get_children():
		var material := (face as MeshInstance3D).material_override as ShaderMaterial
		if material:
			material.set_shader_parameter("body_color", BODY_COLOR)


## Where the game name ends up on screen at the end of the splash ([view_size] pixels): centred, [used] being the pixel rect
## the name occupies in the game.png texture. The loading screen draws its own name there.
static func final_logo_rect(view_size: Vector2, used: Rect2i) -> Rect2:
	var design: DieDesign = Database.get_content("die_designs", DESIGN)
	if design == null and Database.get_all("die_designs").size() > 0:
		design = Database.get_all("die_designs")[0]
	var face_size := design.face_size if design else 0.76
	var pixels_per_unit := view_size.y / (2.0 * tan(deg_to_rad(CAMERA_FOV) * 0.5) * TOP_DISTANCE)
	var scale := face_size * ART_FILL / float(maxi(used.size.x, used.size.y)) * pixels_per_unit
	var size := Vector2(used.size) * scale
	return Rect2(view_size * 0.5 - size * 0.5, size)


# ===========================================================================================================================================
# Embossed art
# ===========================================================================================================================================


## Builds [ink texture, normal texture] for the engine logo, studio logo and game name, in that order. The images are
## worked out on worker threads.
func _build_art() -> Array:
	var sources: Array[Image] = [_readable(ENGINE_LOGO), _readable(STUDIO_LOGO), _readable(GAME_NAME)]
	# Logos on black are cut out by brightness; the game name already has an alpha channel
	var has_alpha: Array[bool] = [false, false, true]
	var images: Array = [null, null, null]
	var task := WorkerThreadPool.add_group_task(func(i: int): images[i] = _emboss_images(sources[i], has_alpha[i]), 3)
	while not WorkerThreadPool.is_group_task_completed(task):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_group_task_completion(task)
	var art: Array = []
	for pair: Array in images:
		art.append([ImageTexture.create_from_image(pair[0]), ImageTexture.create_from_image(pair[1])])
	return art


static func _readable(texture: Texture2D) -> Image:
	var image := texture.get_image()
	if image.is_compressed():
		image.decompress()
	image.convert(Image.FORMAT_RGBA8)
	return image


## [ink image (the logo's colours, alpha = its shape), normal map with the logo raised]. Thread safe.
static func _emboss_images(source: Image, has_alpha: bool) -> Array:
	var logo := _fit_logo(source, has_alpha)
	var pixels := logo.get_data()
	var heights := PackedByteArray()
	heights.resize(ART_SIZE * ART_SIZE)
	for i in heights.size():
		heights[i] = pixels[i * 4 + 3]
	var height := Image.create_from_data(ART_SIZE, ART_SIZE, false, Image.FORMAT_L8, heights)
	height.convert(Image.FORMAT_RGBA8)
	# Blurring the height map bevels the edges
	var soft := ART_SIZE / BLUR_DIVISOR
	# Shrinking and cubic expanding twice gives smooth slopes; one bilinear pass leaves visible creases and steps in the relief
	height.resize(soft, soft, Image.INTERPOLATE_TRILINEAR)
	height.resize(soft * 2, soft * 2, Image.INTERPOLATE_CUBIC)
	height.resize(soft, soft, Image.INTERPOLATE_TRILINEAR)
	height.resize(ART_SIZE, ART_SIZE, Image.INTERPOLATE_CUBIC)
	height.bump_map_to_normal_map(BUMP_SCALE)
	logo.generate_mipmaps()
	height.generate_mipmaps()
	return [logo, height]


## The logo trimmed and scaled to fill a square canvas, with its shape in the alpha channel.
static func _fit_logo(source: Image, has_alpha: bool) -> Image:
	var bounds := _logo_bounds(source, has_alpha)
	var region := source.get_region(bounds)
	var factor := ART_SIZE * ART_FILL / maxi(bounds.size.x, bounds.size.y)
	region.resize(maxi(roundi(bounds.size.x * factor), 1), maxi(roundi(bounds.size.y * factor), 1), Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(ART_SIZE, ART_SIZE, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(1, 1, 1, 0) if has_alpha else Color.BLACK)
	canvas.blit_rect(region, Rect2i(Vector2i.ZERO, region.get_size()), (Vector2i(ART_SIZE, ART_SIZE) - region.get_size()) / 2)
	if not has_alpha:
		var data := canvas.get_data()
		var inside := _inside_mask(canvas)
		for i in range(0, data.size(), 4):
			var shape := clampf((_luminance(data, i) - LUMA_FLOOR) * LUMA_GAIN, 0.0, 1.0)
			data[i + 3] = int(maxf(shape, inside[i / 4] / 255.0) * 255.0)
		canvas.set_data(ART_SIZE, ART_SIZE, false, Image.FORMAT_RGBA8, data)
	return canvas


## Everything the black background doesn't reach from the picture's edge, as an ART_SIZE x ART_SIZE byte mask (255 inside,
## soft edge). Dark outlines and shadows inside the logo count as inside, so they stay solid instead of turning see-through.
static func _inside_mask(canvas: Image) -> PackedByteArray:
	var small: Image = canvas.duplicate()
	small.resize(MASK_SIZE, MASK_SIZE, Image.INTERPOLATE_BILINEAR)
	var data := small.get_data()
	var mask := PackedByteArray()
	mask.resize(MASK_SIZE * MASK_SIZE)
	mask.fill(255)
	var stack := PackedInt32Array()
	for i in MASK_SIZE:
		stack.append(i)
		stack.append((MASK_SIZE - 1) * MASK_SIZE + i)
		stack.append(i * MASK_SIZE)
		stack.append(i * MASK_SIZE + MASK_SIZE - 1)
	while not stack.is_empty():
		var cell: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if mask[cell] == 0 or _luminance(data, cell * 4) > LUMA_FLOOR * 0.5:
			continue
		mask[cell] = 0
		var cx := cell % MASK_SIZE
		if cx > 0:
			stack.append(cell - 1)
		if cx < MASK_SIZE - 1:
			stack.append(cell + 1)
		if cell >= MASK_SIZE:
			stack.append(cell - MASK_SIZE)
		if cell < MASK_SIZE * (MASK_SIZE - 1):
			stack.append(cell + MASK_SIZE)
	var image := Image.create_from_data(MASK_SIZE, MASK_SIZE, false, Image.FORMAT_L8, mask)
	image.resize(ART_SIZE, ART_SIZE, Image.INTERPOLATE_BILINEAR)
	return image.get_data()


## Pixel rectangle the logo occupies.
static func _logo_bounds(source: Image, has_alpha: bool) -> Rect2i:
	var whole := Rect2i(Vector2i.ZERO, source.get_size())
	if has_alpha:
		var used := source.get_used_rect()
		return used if used.has_area() else whole
	var small: Image = source.duplicate()
	small.resize(SCAN_SIZE, SCAN_SIZE, Image.INTERPOLATE_BILINEAR)
	var data := small.get_data()
	var low := Vector2i(SCAN_SIZE, SCAN_SIZE)
	var high := Vector2i.ZERO
	for y in SCAN_SIZE:
		for x in SCAN_SIZE:
			if _luminance(data, (y * SCAN_SIZE + x) * 4) > LUMA_FLOOR:
				low = low.min(Vector2i(x, y))
				high = high.max(Vector2i(x, y))
	if high.x < low.x:
		return whole
	var cell := Vector2i(source.get_width() / SCAN_SIZE, source.get_height() / SCAN_SIZE)
	return Rect2i(low * cell, (high - low + Vector2i.ONE) * cell).grow(maxi(cell.x, cell.y)).intersection(whole)


static func _luminance(data: PackedByteArray, offset: int) -> float:
	return (data[offset] * 0.299 + data[offset + 1] * 0.587 + data[offset + 2] * 0.114) / 255.0
