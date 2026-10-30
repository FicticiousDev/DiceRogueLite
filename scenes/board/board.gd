class_name Board
extends Node3D

## A level's board. The 2D Layout/Markers TileMapLayers are the source of truth: 3D HexTiles are
## built from Layout cells and keyed by Hex.id(cell). All grid queries work on cells/ids.

signal intro_finished

enum Marker { PLAYER_START, ENEMY, OBSTACLE, EXIT }

const HEX_TILE_SCENE: PackedScene = preload("res://scenes/board/hex_tile.tscn")

## World units per layout pixel. 128 px wide cells -> tiles 1 unit wide.
@export var world_scale: float = 1.0 / 128.0
@export var intro_delay_per_ring: float = 0.06

@onready var layout: TileMapLayer = $Layout
@onready var markers: TileMapLayer = $Markers
@onready var tiles_root: Node3D = $Tiles

var tiles: Dictionary[int, HexTile] = {}
var player_start: Vector2i
## Distinct tile-top heights, tallest first. Used for picking.
var _top_heights: Array[float] = []
var _highlighted: Array[int] = []
var _selected: int = -1


func _ready() -> void:
	# Layers are for authoring only
	layout.visible = false
	markers.visible = false
	_build()


func _build() -> void:
	var cell_radius := layout.tile_set.tile_size.y / 2.0 * world_scale
	for cell in layout.get_used_cells():
		var tile: HexTile = HEX_TILE_SCENE.instantiate()
		tile.setup(cell, layout.get_cell_tile_data(cell).get_custom_data("terrain"), cell_radius)
		tile.position = cell_to_local(cell)
		tile.visible = false
		tiles_root.add_child(tile)
		tiles[tile.id] = tile
		if not _top_heights.has(tile.top_height()):
			_top_heights.append(tile.top_height())
	_top_heights.sort()
	_top_heights.reverse()

	var starts := get_marker_cells(Marker.PLAYER_START)
	player_start = starts[0] if starts.size() > 0 else layout.get_used_cells()[0]


## Pops tiles in, rippling out from the player start. Awaitable.
func play_intro() -> void:
	var longest := 0.0
	for tile in tiles.values():
		var delay: float = Hex.distance(player_start, tile.coords) * intro_delay_per_ring
		longest = maxf(longest, delay + tile.intro_duration)
		tile.play_intro(delay)
	await get_tree().create_timer(Anim.t(longest)).timeout
	intro_finished.emit()


# ===========================================================================================================================================
# Queries
# ===========================================================================================================================================


func has_tile(tile_id: int) -> bool:
	return tiles.has(tile_id)


func get_tile(tile_id: int) -> HexTile:
	return tiles.get(tile_id)


## Ids of existing tiles adjacent to [tile_id].
func get_neighbours(tile_id: int) -> Array[int]:
	var result: Array[int] = []
	for cell in Hex.neighbours(Hex.coords(tile_id)):
		var neighbour_id := Hex.id(cell)
		if tiles.has(neighbour_id):
			result.append(neighbour_id)
	return result


func is_walkable(tile_id: int) -> bool:
	return tiles.has(tile_id) and Terrain.is_walkable(tiles[tile_id].terrain)


## Cost to enter [tile_id], or -1 if it can't be entered.
func move_cost(tile_id: int) -> int:
	return Terrain.cost(tiles[tile_id].terrain) if tiles.has(tile_id) else -1


func get_marker_cells(marker: Marker) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for cell in markers.get_used_cells():
		if markers.get_cell_tile_data(cell).get_custom_data("marker") == marker:
			result.append(cell)
	return result


## Board-local bounds of all tiles.
func get_bounds() -> AABB:
	var bounds := AABB()
	var first := true
	for tile in tiles.values():
		var tile_box := AABB(tile.position - Vector3(tile.radius, 0, tile.radius), Vector3(tile.radius * 2, tile.top_height(), tile.radius * 2))
		bounds = tile_box if first else bounds.merge(tile_box)
		first = false
	return Transform3D(global_basis, global_position) * bounds


# ===========================================================================================================================================
# 2D grid <-> 3D
# ===========================================================================================================================================


## Board-local position of a cell's centre at ground level.
func cell_to_local(cell: Vector2i) -> Vector3:
	var p := layout.map_to_local(cell) * world_scale
	return Vector3(p.x, 0.0, p.y)


## Global position of the top centre of a tile (where pieces stand).
func cell_to_world(cell: Vector2i) -> Vector3:
	var top := tiles[Hex.id(cell)].top_height() if tiles.has(Hex.id(cell)) else 0.0
	return to_global(cell_to_local(cell) + Vector3.UP * top)


func world_to_cell(world_position: Vector3) -> Vector2i:
	var p := to_local(world_position) / world_scale
	return layout.local_to_map(Vector2(p.x, p.z))


## Tile id under a screen position, or -1. Intersects the camera ray with each tile-top height, tallest first,
## and takes the first cell whose own height matches, so taller tiles in front win.
func tile_at_screen(camera: Camera3D, screen_position: Vector2) -> int:
	var origin := camera.project_ray_origin(screen_position)
	var direction := camera.project_ray_normal(screen_position)
	for height in _top_heights:
		var hit = Plane(global_basis.y, global_position + global_basis.y * height).intersects_ray(origin, direction)
		if hit == null:
			continue
		var tile_id := Hex.id(world_to_cell(hit))
		if tiles.has(tile_id) and is_equal_approx(tiles[tile_id].top_height(), height):
			return tile_id
	return -1


# ===========================================================================================================================================
# Highlights
# ===========================================================================================================================================


func highlight(tile_ids: Array[int], kind: HexTile.Highlight) -> void:
	for tile_id in tile_ids:
		if tiles.has(tile_id):
			tiles[tile_id].set_highlight(kind)
			_highlighted.append(tile_id)


func select(tile_id: int) -> void:
	if tiles.has(_selected):
		tiles[_selected].set_selected(false)
	_selected = tile_id
	if tiles.has(_selected):
		tiles[_selected].set_selected(true)


func clear_highlights() -> void:
	for tile_id in _highlighted:
		tiles[tile_id].set_highlight(HexTile.Highlight.NONE)
	_highlighted.clear()
	select(-1)
