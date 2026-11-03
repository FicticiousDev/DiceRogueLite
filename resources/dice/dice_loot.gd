class_name DiceLoot
extends RefCounted

## Picks loot dice. The rarity starts at the biome's tier (difficulty 1 = common ... 6 = mythic) and can roll one or
## two tiers higher (capped at mythic); challenge rooms always give the top of that range. The die is a random
## available loot die of that rarity - available meaning DieType.loot and unlocked (only a die or two per higher
## rarity at first). With none available at the rarity, the next rarity up that has one is used (or the nearest
## below if there are none above).

## Chance of the base tier, one tier higher and two tiers higher (level clears, bosses, chests)
const TIER_ODDS: Array[float] = [0.65, 0.28, 0.07]


## A random loot die for a biome of [difficulty], or null if no loot dice are available at all. [top] always
## takes the highest tier (challenge rooms); otherwise the tier rolls by [odds].
static func roll(rng: RandomNumberGenerator, difficulty: int, top: bool = false, odds: Array[float] = TIER_ODDS) -> DieType:
	var tier := clampi(difficulty - 1, 0, Rarity.Tier.MYTHIC)
	var step := odds.size() - 1 if top else roll_step(rng, odds)
	var dice := available(mini(tier + step, Rarity.Tier.MYTHIC))
	return dice[rng.randi() % dice.size()] if dice.size() > 0 else null


## How many tiers above the base a reward rolls: 0, 1 or 2 by [odds]. Shops use it too (ShopStock).
static func roll_step(rng: RandomNumberGenerator, odds: Array[float] = TIER_ODDS) -> int:
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
