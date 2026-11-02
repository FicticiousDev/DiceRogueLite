class_name EquipmentData
extends Resource

## An item of equipment. Its effects are its [member abilities] - passives are always on while it's equipped,
## actives are used like the character's (see Ability). To make a new item: a new .tres in data/equipment/ with
## a slot, rarity and abilities (new effects are a new Ability subclass). The player wears 1 armour, 1 boots and
## 2 charms (RunData.equipment).

enum Slot { ARMOUR, BOOTS, CHARM }

const SLOT_NAMES: Dictionary[Slot, String] = { Slot.ARMOUR: "Armour", Slot.BOOTS: "Boots", Slot.CHARM: "Charm" }
const SLOT_ICONS: Dictionary[Slot, Texture2D] = {
	Slot.ARMOUR: preload("res://assets/equipment/armour.png"),
	Slot.BOOTS: preload("res://assets/equipment/boots.png"),
	Slot.CHARM: preload("res://assets/equipment/charm.png"),
}

@export var id: StringName
@export var display_name: String
@export var slot: Slot = Slot.CHARM
@export var rarity: Rarity.Tier = Rarity.Tier.COMMON
## Optional; defaults to the slot's placeholder icon, tinted by rarity
@export var icon: Texture2D
@export var abilities: Array[Ability] = []
## Added to the player's maximum (and current) health while equipped
@export var max_hp: int = 0
## Can drop as loot (chests, bosses, challenge rooms)
@export var loot: bool = true
## Can drop from the start; otherwise only once in ProgressionData.unlocked_items
@export var starts_unlocked: bool = true


func get_icon() -> Texture2D:
	return icon if icon else SLOT_ICONS[slot]


## Explanation rows for tooltips and the award: each ability (actives with their uses), then any health bonus.
func info_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for ability in abilities:
		var text := "%s: %s" % [ability.display_name, ability.description]
		rows.append(InfoPanel.row(get_icon(), Rarity.COLORS[rarity], text))
	if max_hp != 0:
		rows.append(InfoPanel.row(preload("res://assets/ui/icons/heart.png"), Color(1, 0.35, 0.35), "%+d maximum health." % max_hp))
	return rows


## "Rare Armour" etc.
func kind() -> String:
	return "%s %s" % [Rarity.Tier.keys()[rarity].capitalize(), SLOT_NAMES[slot].to_lower()]
