class_name Rarity
extends RefCounted

## Die rarity tiers. Colour tints the die body; the top tier also glows.

enum Tier { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY, MYTHIC }

const COLORS: Dictionary[Tier, Color] = {
	Tier.COMMON: Color(0.92, 0.9, 0.85),
	Tier.UNCOMMON: Color(0.45, 0.78, 0.42),
	Tier.RARE: Color(0.38, 0.58, 0.92),
	Tier.EPIC: Color(0.62, 0.42, 0.86),
	Tier.LEGENDARY: Color(0.96, 0.6, 0.2),
	Tier.MYTHIC: Color(0.88, 0.14, 0.14),
}

## Localisation keys of the tier names
const NAMES: Dictionary[Tier, String] = {
	Tier.COMMON: "RARITY_COMMON",
	Tier.UNCOMMON: "RARITY_UNCOMMON",
	Tier.RARE: "RARITY_RARE",
	Tier.EPIC: "RARITY_EPIC",
	Tier.LEGENDARY: "RARITY_LEGENDARY",
	Tier.MYTHIC: "RARITY_MYTHIC",
}

## Surface glow for tiers that have one: [facing colour, edge colour]. Emissive, strongest at the silhouette.
const GLOW: Dictionary[Tier, Array] = {
	Tier.MYTHIC: [Color(1.0, 0.78, 0.25), Color(1.0, 0.12, 0.05)],
}


## Translated name of [param tier], e.g. "Rare".
static func display_name(tier: Tier) -> String:
	return TranslationServer.translate(NAMES[tier])
