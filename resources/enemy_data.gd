class_name EnemyData
extends Resource

## An enemy type. Stats are fixed per type.

@export var id: StringName
@export var display_name: String
@export var texture: Texture2D = preload("res://icon.svg")
@export var tint: Color = Color.WHITE
@export var hp: int = 5
@export var move: int = 2
## Damage per hit, before crits and the player's defence
@export var attack: int = 2
@export_range(0.0, 1.0) var crit_chance: float = 0.05
@export_range(0.0, 1.0) var miss_chance: float = 0.05
@export var attack_range: int = 1
## Defence: a bar of this many segments that soaks damage before the ice shield and health (armour piercing bypasses
## it), and recovers one segment at the end of each round
@export var defence: int = 0
## Strikes before the player's attack when retaliating
@export var attacks_first: bool = false
@export var gold: int = 2
## Bosses can't be insta-killed: an insta-kill face hits them for [AttackContext.BOSS_INSTA_KILL_DAMAGE] with a crit instead
@export var is_boss: bool = false
## Status effects its damaging hits give the player
@export var applies_stun: bool = false
@export var applies_poison: bool = false
## Its damaging hits freeze the player (next turn's movement halved) / set them on fire (half the damage again next turn)
@export var applies_freeze: bool = false
@export var applies_fire: bool = false

@export_group("Boss")
## Scale of the cut-out; the piece still stands on one tile
@export var size: float = 1.0
## Attacks in its own turn, each rolled and blocked separately. Retaliating is always a single attack
@export var attacks_per_turn: int = 1
## Stun has no effect on it
@export var stun_immune: bool = false
## Ice shield: takes damage before health (the rest carries over), and recovers [member shield_regen] in any round the
## piece takes no damage
@export var shield: int = 0
@export var shield_regen: int = 0
## Health is split into this many segments: the bar shows the divisions and behaviours react as each one empties
@export var segments: int = 0
## What it summons (and how many it starts the level with)
@export var minion: EnemyData
@export var starting_minions: int = 0
## Unique rules
@export var behaviour: BossBehaviour
## Explains the unique rules in the enemy details, one line per row
@export_multiline var description: String = ""
