extends SceneTree
## Combined title/voxel UI smoke: PNG import, nine-slice styles and actual
## Select Recipe -> Prepare Materials -> Work -> collected-item receipt.
var failed: int = 0

func _initialize() -> void:
	call_deferred("_run")

func verify(ok: bool, message: String) -> void:
	if ok:
		print("PASS PIXEL UI: " + message)
	else:
		failed += 1
		push_error("FAIL PIXEL UI: " + message)

func _run() -> void:
	const FRAMES: Array[String] = ["dark_wood_panel", "item_card", "parchment_panel", "toast_card", "transparent_wood_frame"]
	const BUTTONS: Array[String] = ["green_normal", "red_normal", "wood_normal", "wood_pressed"]
	const ICONS: Array[String] = ["attack", "bag", "craft", "gather", "heal"]
	for frame_id in FRAMES:
		var path: String = "res://assets/ui/frames/" + frame_id + ".png"
		var tex: Texture2D = load(path) as Texture2D
		verify(tex != null and tex.get_size() == Vector2(128, 128), "128x128 imported frame: " + frame_id)
	for button_id in BUTTONS:
		var path: String = "res://assets/ui/buttons/" + button_id + ".png"
		var tex: Texture2D = load(path) as Texture2D
		verify(tex != null and tex.get_size() == Vector2(192, 64), "192x64 button graphic: " + button_id)
	for icon_id in ICONS:
		var path: String = "res://assets/ui/icons/" + icon_id + ".png"
		var tex: Texture2D = load(path) as Texture2D
		verify(tex != null and tex.get_size() == Vector2(128, 128), "128x128 transparent action icon: " + icon_id)
	var skin = load("res://scripts/ui/outpost_skin.gd")
	for style_id in ["frame", "parchment", "wood", "inset", "toast", "item"]:
		var nine: StyleBox = skin.box(style_id)
		verify(nine is StyleBoxTexture and nine.texture != null, "Nine-slice texture applied: " + style_id)
		if nine is StyleBoxTexture:
			verify(is_equal_approx(nine.texture_margin_left, 16.0), "Panel protects original 16px border: " + style_id)
	var test_button := Button.new()
	skin.apply_button(test_button, "wood")
	verify(test_button.get_theme_stylebox("normal") is StyleBoxTexture, "Wood normal button has graphic")
	verify(test_button.get_theme_stylebox("pressed") is StyleBoxTexture, "Wood pressed button has graphic")
	var image: Texture2D = (test_button.get_theme_stylebox("pressed") as StyleBoxTexture).texture
	verify(image != null and image.resource_path.ends_with("wood_pressed.png"), "Pressed state uses the separate pressed PNG")
	test_button.queue_free()
	var game_scene: PackedScene = load("res://scenes/main.tscn")
	verify(game_scene != null, "Game scene remains valid")
	if game_scene == null:
		quit(1)
		return
	var game = game_scene.instantiate()
	root.add_child(game)
	await process_frame
	verify(game.hud != null and game.menu != null, "HUD and crafting interface both initialise")
	verify(game.hud.root.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Game HUD samples PNG pixels without smoothing")
	verify(game.menu.shell.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Craft UI samples panels without smoothing")
	var attack: Button = game.hud.root.get_node_or_null("Action_attack") as Button
	verify(attack != null, "Attack touch button exists")
	if attack != null:
		verify(attack.get_theme_stylebox("normal") is StyleBoxTexture, "Attack action uses graphic red button")
		var icon: TextureRect = attack.get_child(0) as TextureRect
		verify(icon != null and icon.texture != null and icon.texture.resource_path.ends_with("attack.png"), "Attack action shows original PNG icon")
		verify(attack.size.x >= 85 and attack.size.y >= 85, "Attack button is large enough to tap at 1280x720")
	var start_mode: String = str(game.menu.craft_step)
	verify(start_mode == "browse", "Crafting begins on recipe browser")
	game.hero.global_position = game.station_positions["workbench"] + Vector3(0, 0.35, 0)
	game.inventory["wood"] = 7
	game.inventory["stone"] = 5
	game.show_crafting()
	verify(game.menu.visible, "Crafting window opens")
	var frame: PanelContainer = game.menu.shell.get_child(1) as PanelContainer
	verify(frame != null and frame.get_theme_stylebox("panel") is StyleBoxTexture, "Craft window displays a wood-frame PNG")
	game.menu._recipe_change("spear")
	game.menu._begin_prepare()
	verify(game.menu.craft_step == "prepare", "Select Recipe transitions to Prepare Materials")
	game.menu._toggle_ingredient("wood")
	game.menu._toggle_ingredient("stone")
	verify(game.menu.loaded.size() == 2, "Materials individually marked as loaded")
	game.menu._start_craft()
	verify(not game.crafting.is_empty(), "Prepare Materials starts existing manual crafting")
	verify(int(game.inventory.get("wood", 0)) == 7, "Starting production does not prematurely consume ingredients")
	game._update_crafting(10.0)
	verify(int(game.inventory.get("spear", 0)) == 0, "Timer cannot produce equipment without work actions")
	for i in range(3):
		game.craft_work_cooldown = 0.0
		game.work_craft()
	verify(game.crafting.is_empty(), "Craft action completes when all station work is done")
	verify(game.menu.completed_id == "spear", "Collect receipt displays the crafted result")
	verify(int(game.inventory.get("spear", 0)) == 1, "Exactly one spear enters inventory")
	verify(int(game.inventory.get("wood", 0)) == 4 and int(game.inventory.get("stone", 0)) == 3, "Inputs deducted exactly once")
	game.menu._clear_result()
	verify(int(game.inventory.get("spear", 0)) == 1, "Collect receipt acknowledgement never duplicates output")
	game.show_inventory()
	verify(game.menu.current_page == "bag", "Bag remains accessible")
	game.show_equipment()
	verify(game.menu.current_page == "equipment", "Equipment remains accessible")
	verify(game.is_equipped("spear"), "Original equipment loadout preserved")
	game.menu.close_page()
	verify(not game.menu.visible, "Closing UI returns to play")
	game.queue_free()
	await process_frame
	print("PIXEL UI RESULT: %d failure(s)." % failed)
	quit(0 if failed == 0 else 1)
