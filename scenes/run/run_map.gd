class_name RunMap
extends RefCounted

## The whole run's level graph, generated up front and stored in RunData.map. Each node is a Dictionary:
## level (LevelData id), biome (BiomeData id), next (node indices), row (map position) and seed (level population).
## Biomes run 1 -> 2 or 3 -> 4 or 5 -> 6. Each is a layered graph from one entry level to its boss, 4-7 levels
## deep, with one challenge level and a chance of a shop. Node 0 is the start of the run.

const MIN_DEPTH: int = 4
const MAX_DEPTH: int = 7
const SHOP_CHANCE: float = 0.2
const BANK_CHANCE: float = 0.25
## Biome orders each boss leads on to
const BIOME_LINKS: Dictionary[int, Array] = { 1: [2, 3], 2: [4, 5], 3: [4, 5], 4: [6], 5: [6], 6: [] }
## Map rows: the alternative biomes sit above and below the main line
const BIOME_BANDS: Dictionary[int, float] = { 1: 0.0, 2: -1.6, 3: 1.6, 4: -1.6, 5: 1.6, 6: 0.0 }


static func generate() -> Array[Dictionary]:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var nodes: Array[Dictionary] = []
	var biomes := Database.get_all("biomes")
	biomes.sort_custom(func(a: BiomeData, b: BiomeData): return a.order < b.order)
	var entries: Dictionary[int, int] = {}
	var bosses: Dictionary[int, int] = {}
	for biome: BiomeData in biomes:
		var layers := _add_biome(rng, nodes, biome)
		entries[biome.order] = layers[0][0]
		bosses[biome.order] = layers[-1][0]
	for order in bosses:
		for next_order in BIOME_LINKS[order]:
			nodes[bosses[order]].next.append(entries[next_order])
	_choose_levels(nodes)
	return nodes


## Adds one biome's levels as layers of node indices: an entry, middle layers of 2-3 levels, then the boss.
static func _add_biome(rng: RandomNumberGenerator, nodes: Array[Dictionary], biome: BiomeData) -> Array[Array]:
	var depth := rng.randi_range(MIN_DEPTH, MAX_DEPTH)
	var layers: Array[Array] = []
	var middle: Array[int] = []
	for i in depth:
		var width := 1 if i == 0 or i == depth - 1 else rng.randi_range(2, 3)
		var layer: Array[int] = []
		for j in width:
			var type := LevelData.Type.BOSS if i == depth - 1 else LevelData.Type.NORMAL
			layer.append(nodes.size())
			nodes.append({ "level": "", "type": type, "biome": String(biome.id), "next": [], "row": BIOME_BANDS[biome.order] + j - (width - 1) / 2.0, "seed": rng.randi() })
			if i > 0 and i < depth - 1:
				middle.append(layer[-1])
		layers.append(layer)
	for i in depth - 1:
		_connect(rng, nodes, layers[i], layers[i + 1])

	# One challenge level and maybe a shop, somewhere in the middle - not every route passes them
	middle.shuffle()
	nodes[middle[0]].type = LevelData.Type.CHALLENGE
	if rng.randf() < SHOP_CHANCE:
		nodes[middle[1]].type = LevelData.Type.SHOP_BANK if rng.randf() < BANK_CHANCE else LevelData.Type.SHOP
	return layers


## Joins two layers with a random non-crossing staircase, so every level has a way in and a way out. Levels after
## the entry get at most two ways on (shops have two exits).
static func _connect(rng: RandomNumberGenerator, nodes: Array[Dictionary], from: Array, to: Array) -> void:
	var max_out := 3 if from.size() == 1 else 2
	var edges: Array[Vector2i] = []
	while edges.is_empty():
		var i := 0
		var j := 0
		edges = [Vector2i(0, 0)]
		while i < from.size() - 1 or j < to.size() - 1:
			var step := rng.randi_range(0, 2)
			if i == from.size() - 1:
				step = 1
			elif j == to.size() - 1:
				step = 0
			if step != 1:
				i += 1
			if step != 0:
				j += 1
			edges.append(Vector2i(i, j))
		for k in from.size():
			if edges.filter(func(edge: Vector2i): return edge.x == k).size() > max_out:
				edges.clear()
	for edge in edges:
		nodes[from[edge.x]].next.append(to[edge.y])


## Picks a level of each node's type with enough exits, using each level once before any repeats.
static func _choose_levels(nodes: Array[Dictionary]) -> void:
	var unused: Dictionary[int, Array] = {}
	for node in nodes:
		var type: int = node.type
		var fits := func(level: LevelData): return level.type == type and level.exit_count >= node.next.size()
		var candidates: Array = unused.get(type, []).filter(fits)
		if candidates.is_empty():
			unused[type] = Database.get_all("levels").filter(func(level: LevelData): return level.type == type)
			candidates = unused[type].filter(fits)
		var pick: LevelData = candidates.pick_random()
		unused[type].erase(pick)
		node.level = String(pick.id)
		node.erase("type")


# ===========================================================================================================================================
# Queries (saved maps come back from JSON with float numbers)
# ===========================================================================================================================================


static func current_index(run: RunData) -> int:
	return int(run.path[-1])


static func node(run: RunData, index: int) -> Dictionary:
	return run.map[index]


static func next(run: RunData, index: int) -> Array[int]:
	var result: Array[int] = []
	for i in run.map[index].next:
		result.append(int(i))
	return result


static func level(run: RunData, index: int) -> LevelData:
	return Database.get_content("levels", StringName(run.map[index].level))


static func biome(run: RunData, index: int) -> BiomeData:
	return Database.get_content("biomes", StringName(run.map[index].biome))
