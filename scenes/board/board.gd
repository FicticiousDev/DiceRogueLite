class_name Board
extends Node3D

## A level's board. The 2D Layout/Markers TileMapLayers are the source of truth: 3D HexTiles are
## built from Layout cells and keyed by Hex.id(cell). All grid queries, pathfinding and line of sight work on cells/ids.

signal intro_finished

enum Marker { PLAYER_START, ENEMY, OBSTACLE, EXIT }

const HEX_TILE_SCENE: PackedScene = preload("res://scenes/board/hex_tile.tscn")
const OBSTACLE_SCENE: PackedScene = preload("res://scenes/pieces/obstacle.tscn")
const ENEMY_SCENE: PackedScene = preload("res://scenes/pieces/enemy.tscn")
## Distance along the camera ray between picking samples, in world units
const PICK_STEP: float = 0.005

## World units per layout pixel. 128 px wide cells -> tiles 1 unit wide.
@export var world_scale: float = 1.0 / 128.0
@export var intro_delay_per_ring: float = 0.06
## Enemy types for the ENEMY markers, in marker order (sorted by cell), repeating if there are more markers
@export var enemy_ids: Array[StringName] = [&"grunt"]

@onready var layout: TileMapLayer = $Layout
@onready var markers: TileMapLayer = $Markers
@onready var tiles_root: Node3D = $Tiles
@onready var pieces_root: Node3D = $Pieces

var tiles: Dictionary[int, HexTile] = {}
var player_start: Vector2i
## Distinct tile-top heights, tallest first. Picking starts at the tallest.
var _top_heights: Array[float] = []
var _highlighted: Array[int] = []
## Board-local point where the last successful tile_at_screen ray entered the tile (debug overlay)
var last_pick_point: Vector3
## Walkable tiles weighted by terrain cost; tiles with movement-blocking pieces are disabled
var _astar: AStar2D = AStar2D.new()
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

	_build_astar()
	for cell in get_marker_cells(Marker.OBSTACLE):
		add_piece(OBSTACLE_SCENE.instantiate(), cell)
	var enemy_cells := get_marker_cells(Marker.ENEMY)
	enemy_cells.sort()
	for i in enemy_cells.size():
		var enemy: Enemy = ENEMY_SCENE.instantiate()
		enemy.setup(Database.get_content("enemies", enemy_ids[i % enemy_ids.size()]))
		add_piece(enemy, enemy_cells[i])


## Pops tiles in, rippling out from the player start, then drops the pieces in. Awaitable.
func play_intro() -> void:
	var longest := 0.0
	for tile in tiles.values():
		var delay: float = Hex.distance(player_start, tile.coords) * intro_delay_per_ring
		longest = maxf(longest, delay + tile.intro_duration)
		tile.play_intro(delay)
	for piece: BoardPiece in pieces_root.get_children():
		var delay: float = longest * 0.6 + Hex.distance(player_start, Hex.coords(piece.tile_id)) * intro_delay_per_ring
		longest = maxf(longest, delay + piece.intro_duration)
		piece.play_intro(delay)
	await get_tree().create_timer(Anim.t(longest)).timeout
	intro_finished.emit()


# ===========================================================================================================================================
# Pieces
# ===========================================================================================================================================


func add_piece(piece: BoardPiece, cell: Vector2i) -> void:
	pieces_root.add_child(piece)
	piece.place(self, Hex.id(cell))


## Living enemies on the board.
func get_enemies() -> Array[Enemy]:
	var enemies: Array[Enemy] = []
	for piece in pieces_root.get_children():
		if piece is Enemy and not piece.is_dead() and not piece.is_queued_for_deletion():
			enemies.append(piece)
	return enemies


func get_piece(tile_id: int) -> BoardPiece:
	return tiles[tile_id].piece if tiles.has(tile_id) else null


## Updates pathfinding after a tile's occupancy changed. Called by BoardPiece.
func refresh_tile(tile_id: int) -> void:
	if _astar.has_point(tile_id):
		var piece := get_piece(tile_id)
		_astar.set_point_disabled(tile_id, piece != null and piece.blocks_movement)


## Plays the landing effect for the tile's terrain.
func spawn_terrain_effect(tile_id: int) -> void:
	if not tiles.has(tile_id) or not Terrain.EFFECTS.has(tiles[tile_id].terrain):
		return
	var effect: TerrainEffect = Terrain.EFFECTS[tiles[tile_id].terrain].instantiate()
	add_child(effect)
	effect.position = cell_top_local(Hex.coords(tile_id))
	effect.play()


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


## Walkable and not blocked by a piece.
func is_passable(tile_id: int) -> bool:
	var piece := get_piece(tile_id)
	return is_walkable(tile_id) and (piece == null or not piece.blocks_movement)


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


## Board-local position of the top centre of a tile (where pieces stand).
func cell_top_local(cell: Vector2i) -> Vector3:
	var top := tiles[Hex.id(cell)].top_height() if tiles.has(Hex.id(cell)) else 0.0
	return cell_to_local(cell) + Vector3.UP * top


## Global position of the top centre of a tile.
func cell_to_world(cell: Vector2i) -> Vector3:
	return to_global(cell_top_local(cell))


func world_to_cell(world_position: Vector3) -> Vector2i:
	var p := to_local(world_position) / world_scale
	return layout.local_to_map(Vector2(p.x, p.z))


## Tile id under a screen position, or -1. Steps the camera ray down through the grid and returns the first
## tile whose drawn hex prism it enters (top or side), so the result matches what's on screen. A ray that
## slips through the gap between tiles falls back to the cell it was over when it dropped below that tile's top.
func tile_at_screen(camera: Camera3D, screen_position: Vector2) -> int:
	var origin := to_local(camera.project_ray_origin(screen_position))
	var direction := global_basis.inverse() * camera.project_ray_normal(screen_position)
	if direction.y >= 0.0 or _top_heights.is_empty():
		return -1
	var t := (_top_heights[0] - origin.y) / direction.y
	var end := -origin.y / direction.y
	var fallback := -1
	while t <= end:
		var p := origin + direction * t
		var tile_id := Hex.id(layout.local_to_map(Vector2(p.x, p.z) / world_scale))
		if tiles.has(tile_id) and p.y <= tiles[tile_id].top_height():
			var tile := tiles[tile_id]
			if _in_hex(Vector2(p.x - tile.position.x, p.z - tile.position.z), tile.radius * HexTile.BODY_SCALE):
				last_pick_point = p
				return tile_id
			if fallback == -1:
				fallback = tile_id
				last_pick_point = p
		t += PICK_STEP
	return fallback


## Point inside a pointy-top hex (corners on +-Z) of circumradius [r], relative to its centre.
static func _in_hex(v: Vector2, r: float) -> bool:
	var x := absf(v.x)
	return x <= r * sqrt(3.0) / 2.0 and absf(v.y) <= r - x / sqrt(3.0)


# ===========================================================================================================================================
# Pathfinding & line of sight
# ===========================================================================================================================================


## Cheapest path by terrain cost from [from_id] to [to_id] (excluding [from_id]), avoiding blocking pieces.
## Empty if there is no path or the destination is blocked.
func find_path(from_id: int, to_id: int) -> Array[int]:
	var path: Array[int] = []
	if not _astar.has_point(from_id) or not _astar.has_point(to_id) or _astar.is_point_disabled(to_id):
		return path
	# The mover usually stands on (and disables) the start tile
	var start_disabled := _astar.is_point_disabled(from_id)
	_astar.set_point_disabled(from_id, false)
	path.assign(_astar.get_id_path(from_id, to_id))
	_astar.set_point_disabled(from_id, start_disabled)
	if path.size() > 0:
		path.remove_at(0)
	return path


## Fills [ctx].costs/came_from with every tile reachable within its budget (Dijkstra on ctx.cost_func).
## Tiles with a blocking piece can't be entered; the start tile is excluded. Returns the reachable ids
## that can be ended on (no piece occupying them).
func find_reachable(ctx: MoveContext) -> Array[int]:
	ctx.costs = {ctx.start: 0}
	ctx.came_from = {}
	if ctx.teleport:
		return _find_teleport_targets(ctx)
	var frontier: Array[int] = [ctx.start]
	while frontier.size() > 0:
		# Small boards: a linear scan for the cheapest frontier tile is fine
		var best := 0
		for i in range(1, frontier.size()):
			if ctx.costs[frontier[i]] < ctx.costs[frontier[best]]:
				best = i
		var current: int = frontier.pop_at(best)
		for next in get_neighbours(current):
			var step: int = ctx.cost_func.call(next)
			if step < 0 or not (is_passable(next) or ctx.ignores(get_piece(next))):
				continue
			var total: int = ctx.costs[current] + step
			if total <= ctx.budget and (not ctx.costs.has(next) or total < ctx.costs[next]):
				ctx.costs[next] = total
				ctx.came_from[next] = current
				frontier.append(next)
	ctx.costs.erase(ctx.start)

	var result: Array[int] = []
	for tile_id in ctx.costs:
		var piece := get_piece(tile_id)
		if piece == null or ctx.ignores(piece) or not piece.occupies_tile:
			result.append(tile_id)
	return result


## Teleport range: walkable, unoccupied tiles within ctx.budget hexes and in line of sight. Paths are the target only.
func _find_teleport_targets(ctx: MoveContext) -> Array[int]:
	ctx.costs.clear()
	var from := Hex.coords(ctx.start)
	var result: Array[int] = []
	for tile_id in tiles:
		var distance := Hex.distance(from, Hex.coords(tile_id))
		var piece := get_piece(tile_id)
		if distance < 1 or distance > ctx.budget or not is_walkable(tile_id):
			continue
		if piece and not ctx.ignores(piece) and piece.occupies_tile:
			continue
		if has_line_of_sight(ctx.start, tile_id):
			ctx.costs[tile_id] = distance
			ctx.came_from[tile_id] = ctx.start
			result.append(tile_id)
	return result


## True if [to_id] is within [attack_range] hexes of [from_id] with line of sight.
func in_attack_range(from_id: int, to_id: int, attack_range: int) -> bool:
	return Hex.distance(Hex.coords(from_id), Hex.coords(to_id)) <= attack_range and has_line_of_sight(from_id, to_id)


## True if a line between the two tile centres isn't blocked by a wall or a piece that blocks line of sight.
## Lines running exactly along hex edges are tried nudged both ways; either clear line counts.
func has_line_of_sight(from_id: int, to_id: int) -> bool:
	var a := Hex.coords(from_id)
	var b := Hex.coords(to_id)
	for nudge in [1e-6, -1e-6]:
		var clear := true
		for cell in Hex.line(a, b, nudge):
			var tile_id := Hex.id(cell)
			if tile_id != from_id and tile_id != to_id and _blocks_sight(tile_id):
				clear = false
				break
		if clear:
			return true
	return false


func _blocks_sight(tile_id: int) -> bool:
	if not tiles.has(tile_id):
		return false
	var piece := get_piece(tile_id)
	return tiles[tile_id].terrain == Terrain.Type.WALL or (piece != null and piece.blocks_line_of_sight)


func _build_astar() -> void:
	_astar.clear()
	for tile_id in tiles:
		if is_walkable(tile_id):
			var p := cell_to_local(Hex.coords(tile_id))
			_astar.add_point(tile_id, Vector2(p.x, p.z), move_cost(tile_id))
	for tile_id in tiles:
		if _astar.has_point(tile_id):
			for neighbour in get_neighbours(tile_id):
				if _astar.has_point(neighbour):
					_astar.connect_points(tile_id, neighbour)


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
