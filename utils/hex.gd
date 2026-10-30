class_name Hex
extends RefCounted

## Hex grid maths on the TileMapLayer grid.
## Layouts use TILE_LAYOUT_DIAMOND_DOWN, so map coordinates are axial (q, r) and every cell shares the same neighbour offsets.

const NEIGHBOUR_OFFSETS: Array[Vector2i] = [
	Vector2i(1, -1), Vector2i(1, 0), Vector2i(0, 1),
	Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1)
]


## Unique id for a cell. Matches MiceAndDice's TileManager.get_tile_id.
static func id(coords: Vector2i) -> int:
	return (coords.x + 1000) + (coords.y + 1000) * 10000


static func coords(tile_id: int) -> Vector2i:
	return Vector2i(tile_id % 10000 - 1000, tile_id / 10000 - 1000)


static func neighbours(cell: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for offset in NEIGHBOUR_OFFSETS:
		result.append(cell + offset)
	return result


static func distance(a: Vector2i, b: Vector2i) -> int:
	var d := a - b
	return (absi(d.x) + absi(d.y) + absi(d.x + d.y)) / 2


## Cells on the straight line from [a] to [b], inclusive.
## [nudge] shifts the line slightly so lines along hex edges resolve consistently; LOS checks both signs.
static func line(a: Vector2i, b: Vector2i, nudge: float = 1e-6) -> Array[Vector2i]:
	var n := distance(a, b)
	var result: Array[Vector2i] = []
	var ca := Vector3(a.x + nudge, a.y + nudge, -a.x - a.y - 2.0 * nudge)
	var cb := Vector3(b.x + nudge, b.y + nudge, -b.x - b.y - 2.0 * nudge)
	for i in n + 1:
		var t := 0.0 if n == 0 else float(i) / n
		result.append(_cube_round(ca.lerp(cb, t)))
	return result


## Rounds fractional cube coordinates to the nearest cell.
static func _cube_round(c: Vector3) -> Vector2i:
	var rq := roundf(c.x)
	var rr := roundf(c.y)
	var rs := roundf(c.z)
	var dq := absf(rq - c.x)
	var dr := absf(rr - c.y)
	var ds := absf(rs - c.z)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return Vector2i(int(rq), int(rr))
