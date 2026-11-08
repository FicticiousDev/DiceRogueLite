class_name DiceLoot
extends RefCounted

## Picks loot dice. The rarity is rolled from the biome's difficulty (1-6) by [constant TIER_WEIGHTS], or
## [constant TOP_WEIGHTS] for the best rewards (bosses, challenge rooms): commons and uncommons early on, rares and epics
## later, a legendary a lucky find in the third biome (a mythic there about 1 in 50) and a mythic still 1 in 10 at best
## in the last. The die is a random available loot die of that rarity - available meaning DieType.loot and unlocked
## (only a die or two per higher rarity at first). With none available at the rarity, the next rarity up that has one
## is used (or the nearest below if there are none above).

## Weight of each rarity, common to mythic, per biome difficulty 1-6: level clears and chests
const TIER_WEIGHTS: Array[Array] = [
	[60, 32, 8, 0, 0, 0],
	[30, 45, 22, 3, 0, 0],
	[12, 40, 38, 10, 0, 0],
	[4, 24, 45, 24, 3, 0],
	[0, 14, 43, 36, 6, 1],
	[0, 4, 26, 45, 20, 5],
]
## The same for bosses and challenge rooms
const TOP_WEIGHTS: Array[Array] = [
	[0, 55, 40, 5, 0, 0],
	[0, 30, 52, 18, 0, 0],
	[0, 12, 50, 35, 3, 0],
	[0, 4, 38, 48, 8, 2],
	[0, 0, 30, 56, 12, 2],
	[0, 0, 10, 46, 34, 10],
]


## A random loot die for a biome of [difficulty], or null if no loot dice are available at all. [top]: one of the best
## rewards (bosses, challenge rooms).
static func roll(rng: RandomNumberGenerator, difficulty: int, top: bool = false) -> DieType:
	var dice := available(roll_tier(rng, difficulty, top))
	return dice[rng.randi() % dice.size()] if dice.size() > 0 else null


## A rarity for a reward in a biome of [difficulty] (see [constant TIER_WEIGHTS]).
static func roll_tier(rng: RandomNumberGenerator, difficulty: int, top: bool = false) -> int:
	var weights: Array = (TOP_WEIGHTS if top else TIER_WEIGHTS)[clampi(difficulty, 1, 6) - 1]
	var total := 0
	for weight: int in weights:
		total += weight
	var r: float = rng.randf() * total
	for tier in weights.size():
		r -= weights[tier]
		if r < 0.0:
			return tier
	return weights.size() - 1


## How many tiers above a base a reward rolls: 0, 1 or 2 by [odds]. Used by shops (ShopStock).
static func roll_step(rng: RandomNumberGenerator, odds: Array[float]) -> int:
	var r := rng.randf()
	var step := 0
	while step < odds.size() - 1 and r >= odds[step]:
		r -= odds[step]
		step += 1
	return step


## Available loot dice of [tier], or of the next tier up that has any (then down if none above).
static func available(tier: int) -> Array[DieType]:
	var candidates: Array = range(tier, Rarity.Tier.MYTHIC + 1)
	candidates.append_array(range(tier - 1, -1, -1))
	for candidate: int in candidates:
		var dice := loot_dice(candidate)
		if dice.size() > 0:
			return dice
	return []


## Available loot dice of exactly [tier].
static func loot_dice(tier: int) -> Array[DieType]:
	var result: Array[DieType] = []
	for type: DieType in Database.get_all("dice"):
		if type.loot and type.rarity == tier and SaveManager.progression_data.is_die_unlocked(type):
			result.append(type)
	result.sort_custom(func(a: DieType, b: DieType): return String(a.id) < String(b.id))
	return result
