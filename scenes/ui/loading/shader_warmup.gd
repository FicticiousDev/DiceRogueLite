class_name ShaderWarmup
extends Node

## Draws everything in ShaderList, and every die design in an opaque and a glass finish, out of sight so the renderer
## compiles its pipelines now rather than the first time they appear on screen. Two hidden 3D views are drawn side by
## side: one set up like the dice views in menus (own world, transparent background, 4x MSAA, two unshadowed lights) and
## one like the game (shadowed lights, SSAO, the project's MSAA). Items are drawn in batches so progress can be reported.
## Use: await ShaderWarmup.new().run(canvas_host, progress) with progress(done: int, total: int)

const ENVIRONMENT: Environment = preload("res://assets/default_environment.tres")
const DIE_SCENE: PackedScene = preload("res://scenes/dice/die_3d.tscn")
const SAMPLE_DIE: StringName = &"all_rounder"
const VIEW_SIZE: Vector2i = Vector2i(128, 128)
## Frames each batch is drawn for
const BATCH_FRAMES: int = 3
## Extra frames at the end for compiles still running
const SETTLE_FRAMES: int = 10

## Content roots of the two views
var _view_content: Node3D
var _world_content: Node3D
var _canvas_host: Control
var _finishes: Array[DieFinish] = []


func run(canvas_host: Control, progress: Callable) -> void:
	_canvas_host = canvas_host
	_view_content = _make_view(false)
	_world_content = _make_view(true)
	_collect_finishes()

	var batches: Array[Callable] = [_fill_shaders, _fill_materials, _fill_scenes]
	for design: DieDesign in Database.get_all("die_designs"):
		batches.append(_fill_dice.bind(design))
	var total := batches.size() + 1
	for i in batches.size():
		progress.call(i, total)
		await _draw_3d(batches[i])
	progress.call(batches.size(), total)
	await _draw_canvas()
	progress.call(total, total)
	await _frames(SETTLE_FRAMES)


# ===========================================================================================================================================
# Batches. Each adds nodes to one view's content root; it is called once per view.
# ===========================================================================================================================================


func _fill_shaders(content: Node3D) -> void:
	for path in ShaderList.SPATIAL_SHADERS:
		var shader := load(path) as Shader
		if shader == null:
			push_warning("ShaderWarmup: can't load " + path)
			continue
		var material := ShaderMaterial.new()
		material.shader = shader
		_add_quad(content, material)


func _fill_materials(content: Node3D) -> void:
	for material in ShaderList.materials():
		_add_quad(content, material)


func _fill_scenes(content: Node3D) -> void:
	for path in ShaderList.SCENES_3D:
		var scene := load(path) as PackedScene
		if scene:
			content.add_child(scene.instantiate())
		else:
			push_warning("ShaderWarmup: can't load " + path)


## One die in each finish kind with [design]'s mesh.
func _fill_dice(content: Node3D, design: DieDesign) -> void:
	var type: DieType = Database.get_content("dice", SAMPLE_DIE)
	if type == null:
		return
	for finish in _finishes:
		var die: Die3D = DIE_SCENE.instantiate()
		die.setup(-1, type, design)
		die.finish = finish
		die.trim_finish = finish
		die.freeze = true
		die.collision_layer = 0
		die.collision_mask = 0
		content.add_child(die)


## Canvas shaders on small icons under the loading screen's background.
func _draw_canvas() -> void:
	var white := ImageTexture.create_from_image(Image.create_empty(4, 4, false, Image.FORMAT_RGBA8))
	for path in ShaderList.CANVAS_SHADERS:
		var shader := load(path) as Shader
		if shader == null:
			push_warning("ShaderWarmup: can't load " + path)
			continue
		var icon := TextureRect.new()
		icon.texture = white
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.custom_minimum_size = Vector2(8, 8)
		icon.size = Vector2(8, 8)
		var material := ShaderMaterial.new()
		material.shader = shader
		icon.material = material
		_canvas_host.add_child(icon)
	await _frames(BATCH_FRAMES)
	for child in _canvas_host.get_children():
		child.queue_free()


# ===========================================================================================================================================
# Helpers
# ===========================================================================================================================================


## Fills both views with [fill], draws a few frames, then clears them.
func _draw_3d(fill: Callable) -> void:
	for content in [_view_content, _world_content]:
		fill.call(content)
	await _frames(BATCH_FRAMES)
	for content in [_view_content, _world_content]:
		for child in content.get_children():
			child.queue_free()


func _frames(count: int) -> void:
	for i in count:
		await RenderingServer.frame_post_draw


func _add_quad(content: Node3D, material: Material) -> void:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2.ONE * 0.5
	quad.mesh = mesh
	quad.material_override = material
	content.add_child(quad)


## The first opaque and first see-through finish (a die's shaders depend only on which kind it is).
func _collect_finishes() -> void:
	var opaque: DieFinish
	var glass: DieFinish
	for finish: DieFinish in Database.get_all("die_finishes"):
		if finish.is_transparent():
			glass = glass if glass else finish
		else:
			opaque = opaque if opaque else finish
	for finish in [opaque, glass]:
		if finish:
			_finishes.append(finish)


## A hidden 3D view and its content root. [game_like] sets it up like the board, otherwise like a dice view.
func _make_view(game_like: bool) -> Node3D:
	var viewport := SubViewport.new()
	viewport.own_world_3d = true
	viewport.size = VIEW_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if game_like:
		viewport.msaa_3d = get_tree().root.msaa_3d
		viewport.screen_space_aa = get_tree().root.screen_space_aa
	else:
		viewport.transparent_bg = true
		viewport.msaa_3d = Viewport.MSAA_4X
	add_child(viewport)

	var environment: Environment = ENVIRONMENT.duplicate()
	if not game_like:
		environment.background_mode = Environment.BG_CLEAR_COLOR
		environment.ssao_enabled = false
	var world := WorldEnvironment.new()
	world.environment = environment
	viewport.add_child(world)

	var camera := Camera3D.new()
	camera.position = Vector3(0, 0, 3.7)
	viewport.add_child(camera)

	if game_like:
		# The board's sun and the dice tray's light, both shadowed
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-45, 30, 0)
		sun.shadow_enabled = true
		viewport.add_child(sun)
		var tray := DirectionalLight3D.new()
		tray.rotation_degrees = Vector3(-40, 30, 0)
		tray.light_energy = 1.1
		tray.light_cull_mask = 2
		tray.shadow_enabled = true
		tray.shadow_caster_mask = 2
		viewport.add_child(tray)
	else:
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-40, -30, 0)
		key.light_energy = 1.1
		viewport.add_child(key)
		var fill := DirectionalLight3D.new()
		fill.rotation_degrees = Vector3(20, 140, 0)
		fill.light_energy = 0.3
		viewport.add_child(fill)

	var content := Node3D.new()
	viewport.add_child(content)
	return content
