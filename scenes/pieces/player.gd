class_name Player
extends BoardPiece

## The player's piece. Persists across levels; the Run places it on each board's player start.

## Until characters define it (Phase 08)
@export var attack_range: int = 1
