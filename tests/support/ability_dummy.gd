extends Node3D
## Isolated damage receiver for actual AoE and armour-status regression tests.
var alive: bool = true
var damage_taken: float = 0.0
var hit_count: int = 0
var burn_seconds: float = 0.0

func _ready() -> void:
	add_to_group("enemies")

func receive_damage(amount: float) -> void:
	damage_taken += amount
	hit_count += 1

func ignite(seconds: float = 4.0) -> void:
	burn_seconds = maxf(burn_seconds, seconds)
