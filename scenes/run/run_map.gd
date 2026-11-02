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
	# A challenge must never be a level's only way on: prefer a spot where that's already true
	middle.shuffle()
	var sole_way := func(index: int) -> bool:
		return nodes.any(func(node: Dictionary): return node.next.size() == 1 and int(node.next[0]) == index)
	var spot := middle.find_custom(func(index: int): return not sole_way.call(index))
	if spot > 0:
		var swap := middle[0]
		middle[0] = middle[spot]
		middle[spot] = swap
	nodes[middle[0]].type = LevelData.Type.CHALLENGE
	_ensure_alternative(nodes, layers, middle[0])
	if rng.randf() < SHOP_CHANCE:
		nodes[middle[1]].type = LevelData.Type.SHOP_BANK if rng.randf() < BANK_CHANCE else LevelData.Type.SHOP
	return layers


## For when every middle spot is some level's only way on: a level whose sole link is [challenge] also gets the
## challenge's neighbour in its layer, on a side where the new link doesn't cross another (either side if both would).
static func _ensure_alternative(nodes: Array[Dictionary], layers: Array[Array], challenge: int) -> void:
	var at := layers.find_custom(func(layer: Array): return layer.has(challenge))
	var layer: Array = layers[at]
	var before: Array = layers[at - 1]
	var j := layer.find(challenge)
	# Lowest / highest position each earlier level links to in the challenge's layer
	var reach := func(node_index: int, lowest: bool) -> int:
		var positions: Array = nodes[node_index].next.map(func(n: int): return layer.find(n)).filter(func(p: int): return p != -1)
		return positions.min() if lowest else positions.max()
	for k in before.size():
		var node: Dictionary = nodes[before[k]]
		if node.next.size() != 1 or int(node.next[0]) != challenge:
			continue
		var options: Array[int] = []
		if j + 1 < layer.size() and before.slice(k + 1).all(func(p: int): return reach.call(p, true) > j):
			options.append(layer[j + 1])
		if j > 0 and before.slice(0, k).all(func(p: int): return reach.call(p, false) < j):
			options.append(layer[j - 1])
		if options.is_empty():
			options.append(layer[j + 1] if j + 1 < layer.size() else layer[j - 1])
		node.next.append(options[0])


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


## Picks a level of each node's type, sized for its biome's stage (shops fit any), with enough exits, using each
## level once before any repeats.
static func _choose_levels(nodes: Array[Dictionary]) -> void:
	var unused: Dictionary[String, Array] = {}
	for node in nodes:
		var type: int = node.type
		var biome: BiomeData = Database.get_content("biomes", StringName(node.biome))
		var stage := 0 if type in [LevelData.Type.SHOP, LevelData.Type.SHOP_BANK] else biome.stage()
		var key := "%d:%d" % [type, stage]
		var fits := func(level: LevelData): return level.exit_count >= node.next.size()
		var candidates: Array = unused.get(key, []).filter(fits)
		if candidates.is_empty():
			unused[key] = Database.get_all("levels").filter(func(level: LevelData): return level.type == type and (stage == 0 or level.stage == stage))
			candidates = unused[key].filter(fits)
		var pick: LevelData = candidates.pick_random()
		unused[key].erase(pick)
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
