class_name EquipmentLoot
extends RefCounted

## Picks loot equipment. Any rarity can drop at any point in the run, but the odds skew towards the biome's tier
## (difficulty 1 = common ... 6 = mythic): each tier away is [constant SKEW] times as likely. [at_least] drops
## tiers below the biome's (challenge rooms). With no available item at the rolled tier, the next tier up that has
## one is used (then down) - as with dice.

const SKEW: float = 0.4


## A random available item for a biome of [difficulty], or null if none are available.
static func roll(rng: RandomNumberGenerator, difficulty: int, at_least: bool = false) -> EquipmentData:
	var base := clampi(difficulty - 1, 0, Rarity.Tier.MYTHIC)
	var weights: Array[float] = []
	var total := 0.0
	for tier in Rarity.Tier.size():
		var weight := 0.0 if at_least and tier < base else pow(SKEW, absi(tier - base))
		weights.append(weight)
		total += weight
	var r := rng.randf() * total
	var tier := 0
	while tier < weights.size() - 1 and r >= weights[tier]:
		r -= weights[tier]
		tier += 1
	var items := available(tier)
	return items[rng.randi() % items.size()] if items.size() > 0 else null


## Available loot items of [tier], or of the next tier up that has any (then down if none above).
static func available(tier: int) -> Array[EquipmentData]:
	var candidates: Array = range(tier, Rarity.Tier.MYTHIC + 1)
	candidates.append_array(range(tier - 1, -1, -1))
	for candidate: int in candidates:
		var result: Array[EquipmentData] = []
		for item: EquipmentData in Database.get_all("equipment"):
			if item.loot and item.rarity == candidate and SaveManager.progression_data.is_item_unlocked(item):
				result.append(item)
		if result.size() > 0:
			return result
	return []
