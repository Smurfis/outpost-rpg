extends "res://scripts/world/mine_goblin.gd"
## Combat, pursuit and death effects are shared with the physical mine.
var encounter_id: String

func receive_damage(amount: float) -> void:
	if not alive:
		return
	super.receive_damage(amount)
	var game = hero.game
	game.natural_cave_encounters[encounter_id] = maxf(0.0, hp)
	if alive:
		game._save()
	else:
		game.on_enemy_killed("goblin")
