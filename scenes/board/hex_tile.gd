class_name HexTile
extends Node3D

## A 3D tile placed from a cell of the board's 2D Layout layer, linked to it by [id] and [coords].

enum Highlight { NONE, VALID, INVALID, MOVABLE, TARGET }

const HIGHLIGHT_COLORS: Dictionary[Highlight, Color] = {
	Highlight.VALID: Color(0.35, 1.0, 0.45, 0.5),
	Highlight.INVALID: Color(1.0, 0.3, 0.3, 0.5),
	Highlight.MOVABLE: Color(0.35, 0.65, 1.0, 0.5),
	Highlight.TARGET: Color(1.0, 0.55, 0.1, 0.6),
}
const SELECTED_COLOR: Color = Color(1.0, 1.0, 1.0, 0.45)
const MARK_COLOR: Color = Color(0.7, 0.35, 1.0)
const WARNING_COLOR: Color = Color(1.0, 0.2, 0.15, 0.6)
## Body radius as a fraction of the cell radius, leaving a small gap between tiles
const BODY_SCALE: float = 0.95
## Circumradius of the tile models in assets/tiles/models; bodies are scaled to fit the cell
const MODEL_RADIUS: float = 0.55

@export var intro_duration: float = 0.6
@export var intro_drop: float = 1.5
@export var outro_duration: float = 0.35
@export var retile_duration: float = 0.5

@onready var body: MeshInstance3D = $Body
@onready var highlight_mesh: MeshInstance3D = $Highlight
@onready var selected_mesh: MeshInstance3D = $Selected

var id: int
var coords: Vector2i
var terrain: Terrain.Type
var radius: float
## Supplies the tile's model, texture and fallback colour. Null uses the Terrain defaults.
var biome: BiomeData
var highlight: Highlight = Highlight.NONE
## Piece standing on this tile, if any. Set by BoardPiece.
var piece: BoardPiece
var played: bool = false
var _warning: MeshInstance3D

# Shared between all tiles, keyed by biome/terrain/highlight
static var _body_materials: Dictionary = {}
static var _overlay_meshes: Dictionary = {}
static var _materials: Dictionary = {}


## Call before adding to the tree.
func setup(cell: Vector2i, type: Terrain.Type, cell_radius: float, tile_biome: BiomeData) -> void:
	coords = cell
	id = Hex.id(cell)
	terrain = type
	radius = cell_radius
	biome = tile_biome


func _ready() -> void:
	highlight_mesh.mesh = _get_overlay_mesh(0.8)
	selected_mesh.mesh = _get_overlay_mesh(0.95)
	selected_mesh.material_override = _get_overlay_material(SELECTED_COLOR)
	_apply_terrain()
	clear_highlights()


func _apply_terrain() -> void:
	body.mesh = biome.terrain_mesh(terrain) if biome else Terrain.MESHES[terrain]
	body.material_override = _get_body_material()
	var fit := radius * BODY_SCALE / MODEL_RADIUS
	body.scale = Vector3(fit, 1.0, fit)
	highlight_mesh.position.y = top_height() + 0.01
	selected_mesh.position.y = top_height() + 0.02
	if _warning:
		_warning.position.y = top_height() + 0.015


## Turns the tile into [type] in [tile_biome]'s look: it pinches in, changes and springs back. Awaitable.
func retile(type: Terrain.Type, tile_biome: BiomeData) -> void:
	var pinch := create_tween()
	pinch.tween_property(self, "scale", Vector3(0.7, 1.0, 0.7), Anim.t(retile_duration * 0.3)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await pinch.finished
	terrain = type
	biome = tile_biome
	_apply_terrain()
	var spring := create_tween()
	spring.tween_property(self, "scale", Vector3.ONE, Anim.t(retile_duration * 0.7)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	await spring.finished


## World-space height of the tile's top surface, relative to the board.
func top_height() -> float:
	return Terrain.HEIGHTS[terrain]


# ===========================================================================================================================================
# Highlights
# ===========================================================================================================================================


func set_highlight(kind: Highlight) -> void:
	highlight = kind
	highlight_mesh.visible = kind != Highlight.NONE
	if highlight_mesh.visible:
		highlight_mesh.material_override = _get_overlay_material(HIGHLIGHT_COLORS[kind])


func set_selected(selected: bool) -> void:
	selected_mesh.visible = selected


func clear_highlights() -> void:
	set_highlight(Highlight.NONE)
	set_selected(false)


## Shows or hides a pulsing red overlay: an attack will land on this tile.
func set_warning(on: bool) -> void:
	if not on:
		if _warning:
			_warning.queue_free()
			_warning = null
		return
	if _warning:
		return
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = WARNING_COLOR
	_warning = MeshInstance3D.new()
	_warning.mesh = _get_overlay_mesh(0.9)
	_warning.material_override = material
	_warning.position.y = top_height() + 0.015
	_warning.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_warning)
	var pulse := _warning.create_tween().set_loops()
	pulse.tween_property(material, "albedo_color:a", WARNING_COLOR.a * 0.35, Anim.t(0.6)).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(material, "albedo_color:a", WARNING_COLOR.a, Anim.t(0.6)).set_trans(Tween.TRANS_SINE)


# ===========================================================================================================================================
# Intro
# ===========================================================================================================================================


func play_intro(delay: float = 0.0) -> void:
	if played:
		return
	played = true
	visible = false

	await get_tree().create_timer(Anim.t(delay)).timeout

	visible = true
	var end_pos := position
	position.y += intro_drop
	scale = Vector3.ONE * 0.01

	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE, Anim.t(intro_duration)).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position", end_pos, Anim.t(intro_duration * 0.6)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Marks the tile with a glowing ring (a boss's special tile).
func show_marked() -> void:
	var ring := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.5
	mesh.outer_radius = radius * 0.68
	mesh.rings = 24
	mesh.ring_segments = 6
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = MARK_COLOR
	mesh.material = material
	ring.mesh = mesh
	ring.scale = Vector3(1.0, 0.05, 1.0)
	ring.position.y = top_height() + 0.02
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ring)
	var pulse := ring.create_tween().set_loops()
	pulse.tween_property(material, "albedo_color", MARK_COLOR.lightened(0.45), Anim.t(0.9)).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(material, "albedo_color", MARK_COLOR, Anim.t(0.9)).set_trans(Tween.TRANS_SINE)


## Appears in place with no animation.
func show_now() -> void:
	played = true
	visible = true


## Shrinks away, rising. The reverse of the intro.
func play_outro(delay: float = 0.0) -> void:
	await get_tree().create_timer(Anim.t(delay)).timeout
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE * 0.01, Anim.t(outro_duration)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", position.y + intro_drop, Anim.t(outro_duration)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await tween.finished
	visible = false


# ===========================================================================================================================================
# Meshes
# ===========================================================================================================================================


func _get_body_material() -> Material:
	var key := "%s:%d" % [biome.id if biome else &"", terrain]
	if not _body_materials.has(key):
		var material := StandardMaterial3D.new()
		material.roughness = 0.9
		var texture: Texture2D = biome.terrain_texture(terrain) if biome else null
		if texture:
			material.albedo_texture = texture
		elif biome and terrain < biome.terrain_colors.size():
			material.albedo_color = biome.terrain_colors[terrain]
		else:
			material.albedo_color = Terrain.COLORS[terrain]
		_body_materials[key] = material
	return _body_materials[key]


func _get_overlay_mesh(size: float) -> Mesh:
	var key := "%f:%f" % [radius, size]
	if not _overlay_meshes.has(key):
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 6
		mesh.rings = 1
		mesh.top_radius = radius * size
		mesh.bottom_radius = radius * size
		mesh.height = 0.01
		_overlay_meshes[key] = mesh
	return _overlay_meshes[key]


func _get_overlay_material(color: Color) -> Material:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.albedo_color = color
		_materials[color] = material
	return _materials[color]
