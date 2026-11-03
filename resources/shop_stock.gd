class_name ShopStock
extends RefCounted

## Picks a shop's offers and prices them by rarity. A shop offers [constant OFFERS] different dice or items (each
## [constant ITEM_CHANCE] an item). Rarity follows the number of biomes visited this run (BiomeData.stage, 1-4): with
## rarities numbered common = 1 ... mythic = 6, one offer is always rarer than that count (the first biome's shop has
## an uncommon or better, the last biome's a legendary or better); the others roll like a level award from the tier
## at that count (DiceLoot.roll_step: 45% that tier, 45% one higher, 10% two higher). When a tier has nothing left
## (unavailable, or already on sale), the next tier up that has something is used (then down), as with loot.

const OFFERS: int = 3
const ITEM_CHANCE: float = 0.5
## Price per rarity, common to mythic
const PRICES: Array[int] = [10, 20, 35, 55, 80, 120]


## Offers for a shop after [visited] biomes, in random order. Seed [rng] for a stock that repeats.
static func roll(rng: RandomNumberGenerator, visited: int) -> Array[Resource]:
	var base := clampi(visited - 1, 0, Rarity.Tier.MYTHIC)
	# The guaranteed rarer offer is picked first, so it never has to fall back below its tier
	var tiers: Array[int] = [mini(base + 1, Rarity.Tier.MYTHIC)]
	for i in OFFERS - 1:
		tiers.append(mini(base + DiceLoot.roll_step(rng), Rarity.Tier.MYTHIC))
	var offers: Array[Resource] = []
	for tier in tiers:
		var offer := _pick(rng, tier, offers)
		if offer:
			offers.append(offer)
	for i in range(offers.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := offers[i]
		offers[i] = offers[j]
		offers[j] = swap
	return offers


## Gold for a die or item, by its rarity.
static func price(offer: Resource) -> int:
	return PRICES[int(offer.get("rarity"))]


## A random available die or item of [tier] that isn't in [taken]. Falls back to the other kind, then to the next
## tier up that has one (then down).
static func _pick(rng: RandomNumberGenerator, tier: int, taken: Array[Resource]) -> Resource:
	var item_first := rng.randf() < ITEM_CHANCE
	var tiers: Array = range(tier, Rarity.Tier.MYTHIC + 1)
	tiers.append_array(range(tier - 1, -1, -1))
	for candidate: int in tiers:
		for items in [item_first, not item_first]:
			var choices: Array = EquipmentLoot.available(candidate) if items else DiceLoot.loot_dice(candidate)
			choices = choices.filter(func(offer: Resource): return not taken.has(offer) and offer.get("rarity") == candidate)
			if choices.size() > 0:
				return choices[rng.randi() % choices.size()]
	return null
