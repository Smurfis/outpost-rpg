extends SceneTree
## Alpha menu & ability medallions preserve real bindings and live controls.
var failures: int = 0
func verify(ok: bool, message: String) -> void:
	if ok:
		print("PASS MENU SKILL ART: " + message)
	else:
		failures += 1
		push_error("FAIL MENU SKILL ART: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.set_meta("outpost_new_adventure", true)
	var scene: PackedScene = load("res://scenes/main.tscn")
	verify(scene != null, "Game scene imports")
	if scene == null:
		quit(1)
		return
	var game = scene.instantiate()
	game.save_path = "user://menu_skill_art_check.json"
	root.add_child(game)
	await process_frame
	var hud = game.hud
	var expected: Array[String] = ["heroic_strike", "armor_break", "whirlwind"]
	for i in range(3):
		var btn: Button = hud.quick_buttons["skill_%d" % (i + 1)] as Button
		var art: TextureRect = btn.get_node_or_null("ActionIcon") as TextureRect
		verify(art != null and art.texture != null and art.texture.resource_path.ends_with(expected[i] + ".svg"),
			"Ability %d has an independent %s icon" % [i + 1, expected[i]])
		verify(btn.get_node_or_null("CooldownRing") != null, "Ability %d retains its radial timer" % (i + 1))
	verify(game.LEVELS.skill_for_slot(0) == "power_strike"
		and game.LEVELS.skill_for_slot(1) == "armor_break"
		and game.LEVELS.skill_for_slot(2) == "whirlwind",
		"Weapon ability bindings match Heroic Strike, Armor Break and Whirlwind")
	var bag: Button = hud.wallet_bag
	var menubtn: Button = hud.menu_button
	for item in [bag, menubtn]:
		verify(item.get_theme_stylebox("normal") is StyleBoxTexture
			and item.get_theme_stylebox("disabled") is StyleBoxTexture,
			"Top chrome uses the same gold-ring frames as Interact")
	verify((bag.get_node("ActionIcon") as TextureRect).texture.resource_path.ends_with("backpack.svg"),
		"Top backpack has matching source artwork")
	verify((menubtn.get_node("ActionIcon") as TextureRect).texture.resource_path.ends_with("menu.svg"),
		"Top menu has matching source artwork")
	var menu_art: Dictionary = {
		"SettingsMenuButton": "settings", "Action_gear": "armour",
		"BagMenuButton": "backpack", "SkillMenuButton": "skills",
		"JournalMenuButton": "quests", "ExitDoorMenuButton": "exit"
	}
	verify(hud.top_menu_actions.size() == 6, "All six real menu actions remain")
	for btn in hud.top_menu_actions:
		var desired: String = str(menu_art.get(btn.name, ""))
		verify(desired != "", btn.name + " is a real expected menu action")
		var art: TextureRect = btn.get_node_or_null("ActionIcon") as TextureRect
		if art == null:
			art = btn.get_node_or_null("MenuIcon") as TextureRect
		if art == null:
			art = btn.get_node_or_null("ExitDoorIcon") as TextureRect
		verify(art != null and art.texture != null and art.texture.resource_path.ends_with(desired + ".svg"),
			btn.name + " includes original matching art")
		verify(btn.pressed.get_connections().size() > 0, btn.name + " retains its click handler")
	game.queue_free()
	await process_frame
	print("MENU SKILL ART RESULT: %d failures" % failures)
	quit(0 if failures == 0 else 1)
