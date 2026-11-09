extends SceneTree
## Snapshot-driven HUD cleanup: no boar assumptions, no Ouch toast,
## actual persisted gathering mastery, world-space receipts and compact XP orb.
const GUARDIAN = preload("res://scripts/dungeons/dungeon_guardian.gd")
var failures: int = 0
const SAVE_PATH: String = "user://hud_skill_world_receipt_test.json"

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, label: String) -> void:
	if ok:
		print("PASS WORLD SKILL HUD: " + label)
	else:
		failures += 1
		push_error("FAIL WORLD SKILL HUD: " + label)

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var packed: PackedScene = load("res://scenes/main.tscn")
	verify(packed != null, "Playable world imports with new trained-skill radial")
	if packed == null:
		quit(1)
		return
	var game = packed.instantiate()
	game.save_path = SAVE_PATH
	root.add_child(game)
	await process_frame
	var hud = game.hud
	verify(not hud.hero_detail.visible, "Training Blade text no longer crowds the character portrait")
	verify(not hud.gathered_panel.visible and not hud.gathered_content.visible, "Permanent gathered-items card is hidden")
	hud.record_gather("wood", 1)
	verify(hud.gathered_entries.size() == 1 and not hud.gathered_panel.visible, "Gather history survives without duplicated overlays")
	game._show_gather_pickup(game.hero.global_position, "wood", 2)
	var floating: Label3D = game.get_node_or_null("FloatingGatherReceipt") as Label3D
	verify(floating != null and floating.text == "+2 Wood", "Gathering produces one live +2 Wood label above hero")
	verify(floating != null and floating.global_position.y > game.hero.global_position.y + 2.0, "Pickup label is above player head, not at resource node")
	verify(floating != null and floating.modulate.a < 1.0, "World-space pickup text is translucent")

	game.gain_gathering_skill("wood", 4)
	verify(int(game.gathering_skill_xp.get("woodcutting", 0)) == 4, "Woodcutting mastery XP is actually earned")
	verify(hud.trained_skill_orb.skill_id == "woodcutting", "Radial shows currently trained woodcutting")
	verify(absf(hud.trained_skill_orb.progress - (4.0 / 60.0)) < 0.001, "Radial progress uses real 60-XP mastery threshold")
	game.gain_gathering_skill("stone", 6)
	verify(hud.trained_skill_orb.skill_id == "mining" and game.gathering_skill_xp["mining"] == 6, "Mining changes active icon and persists real XP")
	game.gain_weapon_mastery("spear", 12)
	verify(hud.trained_skill_orb.skill_id == "spear" and hud.trained_skill_orb.skill_xp == 12, "Weapon attacks update the same live skill radial")
	verify(hud.trained_skill_orb.icon != null and hud.trained_skill_orb.icon.texture != null, "Real skill icon texture is present")
	verify(hud.xp_bar.get_theme_stylebox("background") is StyleBoxFlat and
			(hud.xp_bar.get_theme_stylebox("background") as StyleBoxFlat).bg_color.a < 0.50,
			"Character XP bar uses translucent background")

	var guardian = GUARDIAN.new()
	guardian.name = "CryptGuardian"
	game.add_child(guardian)
	guardian.add_to_group("dungeon_guardians")
	verify(game.enemy_display_name(guardian) == "Crypt Guardian", "Dungeon mob uses its own real display name, never Boar")
	guardian.queue_free()
	var boar := Node.new()
	boar.name = "WildBoar"
	game.add_child(boar)
	verify(game.enemy_display_name(boar) == "Wild boar", "Real wild boars keep their proper species label")
	boar.queue_free()

	hud.toast_panel.visible = false
	hud.toast_label.visible = false
	hud.toast_time = 0.0
	var hp_before: float = game.hero.health
	game.hero.take_hit(9.0)
	verify(game.hero.health < hp_before and not hud.toast_panel.visible, "Player damage updates real health and does NOT show an Ouch banner")
	game._save()
	verify(FileAccess.file_exists(SAVE_PATH), "Legacy-compatible character save includes gathering skill XP")

	# Reload into a new instance so this verifies serialization, not just
	# a single in-memory Dictionary reference.
	game.queue_free()
	await process_frame
	var restored = packed.instantiate()
	restored.save_path = SAVE_PATH
	root.add_child(restored)
	await process_frame
	verify(int(restored.gathering_skill_xp.get("woodcutting", 0)) == 4 and
			int(restored.gathering_skill_xp.get("mining", 0)) == 6,
			"Woodcutting and Mining skill mastery persist through actual save/load")
	verify(restored.hud.trained_skill_orb.skill_id == "spear" and restored.hud.trained_skill_orb.skill_xp == 12,
			"Last trained skill and real radial progress restore on Continue")
	restored.queue_free()
	await process_frame
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	print("WORLD SKILL HUD RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
