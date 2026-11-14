extends SceneTree
## Headless smoke check. Godot 4.7.2:
## godot --headless --path . -s res://tests/alpha_ranger_portrait_character.gd
var failures: int = 0

func check(ok: bool, label: String) -> void:
	if ok:
		print("PASS RANGER: " + label)
	else:
		failures += 1
		push_error("FAIL RANGER: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in [
		"res://assets/ui/icons/hero_portrait_v3.svg",
		"res://assets/ui/icons/portrait_laurel_gold.svg",
		"res://assets/ui/icons/hero_level_medallion.svg"
	]:
		var art: Texture2D = load(path) as Texture2D
		check(art != null and art.get_width() >= 64, "Ranger HUD art loads: " + path)
	var character = load("res://scripts/voxel/voxel_character.gd")
	for part in ["adventurer_torso", "adventurer_head", "adventurer_arm", "adventurer_leg"]:
		var model: MeshInstance3D = character.create_part(part)
		check(model != null and model.mesh != null, part + " renders with the shared voxel atlas")
	var main: PackedScene = load("res://scenes/main.tscn")
	check(main != null, "Game scene loads")
	if main == null:
		quit(1)
		return
	root.set_meta("outpost_new_adventure", true)
	var game = main.instantiate()
	root.add_child(game)
	await process_frame
	var hud = game.hud
	check(hud.hero_portrait_art.texture.resource_path.ends_with("hero_portrait_v3.svg"),
		"Portrait uses the matching new ranger artwork")
	var laurel: TextureRect = hud.root.get_node_or_null("HeroPortraitLaurel") as TextureRect
	check(laurel != null and laurel.mouse_filter == Control.MOUSE_FILTER_IGNORE,
		"Laurel ornament overlays the portrait without consuming taps")
	var medallion = hud.root.get_node_or_null("CharacterLevelBadgeFrame/CharacterLevelMedallionArt")
	check(medallion != null, "Level medallion under live level number")
	var portrait: Rect2 = hud.hero_portrait_frame.get_global_rect()
	var hp: Rect2 = hud.health_bar.get_global_rect()
	check(hp.position.x >= portrait.end.x and hp.position.x - portrait.end.x <= 11.0,
		"HP/MP chrome remains in the approved position")
	check(absf(hud.xp_bar.get_global_rect().end.y - game.get_viewport().get_visible_rect().size.y) < 1.1,
		"XP bar is still flush with bottom screen edge")
	check(hud.quick_buttons.has("potion") and hud.quick_buttons.has("skill_1"),
		"Existing quick controls remain wired")
	game.queue_free()
	await process_frame
	print("RANGER PASS: %d failure(s)" % failures)
	quit(0 if failures == 0 else 1)
