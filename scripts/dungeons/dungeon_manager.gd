extends Node3D
## Outpost dungeon integration layer. Register/unregister procedural chunks from v4.
## A separate save prevents conflicts with existing crafting/gear progression.
const RARITY = preload("res://scripts/dungeons/dungeon_rarity.gd")
const PORTAL = preload("res://scripts/dungeons/dungeon_portal.gd")
const INSTANCE = preload("res://scripts/dungeons/dungeon_instance.gd")
const THEME = preload("res://scripts/ui/material_theme.gd")
const LAYOUT = preload("res://scripts/dungeons/dungeon_layout.gd")
const MINIMAP = preload("res://scripts/dungeons/dungeon_minimap.gd")
@export var save_path: String = "user://outpost_dungeon_clear_v1.json"
const INTERACTION_RADIUS: float = 3.25

@export var demo_chunk_fallback: bool = true

var game
var hero: CharacterBody3D
var chunks: Dictionary = {}
var entrances: Dictionary = {}
var completed_ids: Dictionary = {}
var floor_checkpoints: Dictionary = {}
var active_bonus_id: int = -1
var minimap: Control
var active_instance
var active_info: Dictionary = {}
var return_position: Vector3 = Vector3.ZERO
var run_number: int = 0
var approaching_portal: Area3D
var approaching_chest: bool = false
var chosen_portal: Area3D
var nearest_portal: Area3D

var interface_layer: CanvasLayer
var action_button: Button
var leave_button: Button
var progress_label: Label
var dimmer: ColorRect
var dialog_title: Label
var dialog_message: Label
var confirm_button: Button

func _ready() -> void:
	_load_clears()
	_build_interface()
	call_deferred("_bind_game")

func _bind_game() -> void:
	game = get_parent()
	if game == null:
		return
	var ref: Variant = game.get("hero")
	if ref == null or not (ref is CharacterBody3D):
		# Parent must have completed its _ready() before the dungeon node binds.
		push_warning("DungeonManager waiting for Outpost player initialization")
		return
	hero = ref as CharacterBody3D
	if demo_chunk_fallback:
		_register_demo_chunks()

# v4 world streamer calls this for each loaded chunk. 'bounds' maps X/Z in
# world space. Pass terrain-approved placement positions to avoid blocked doors.
# When placements is nonempty, only those candidate slots are attempted.
func register_chunk(chunk_key: String, bounds: Rect2, chunk_quality: int, placements: Array = [], force_quality: bool = false) -> void:
	if chunk_key.is_empty() or chunks.has(chunk_key):
		return
	var quality: int = RARITY.bounded(chunk_quality)
	var random := RandomNumberGenerator.new()
	random.seed = int(absi(hash(chunk_key)) + 51879)
	var maximum: int = RARITY.max_entrances(quality)
	if not placements.is_empty():
		maximum = mini(maximum, placements.size())
	var owned: Array[String] = []
	for index in range(maximum):
		var entrance_id: String = "%s:%d" % [chunk_key, index]
		if completed_ids.has(entrance_id):
			continue
		var site: Vector3
		if not placements.is_empty():
			if not (placements[index] is Vector3):
				continue
			site = placements[index]
		else:
			var margin_x: float = maxf(2.8, bounds.size.x * 0.17)
			var margin_z: float = maxf(2.8, bounds.size.y * 0.17)
			var x: float = random.randf_range(bounds.position.x + margin_x, bounds.end.x - margin_x)
			var z: float = random.randf_range(bounds.position.y + margin_z, bounds.end.y - margin_z)
			site = Vector3(x, 0.0, z)
		var entrance_quality: int = quality if force_quality else RARITY.roll_quality(quality, random)
		var portal = PORTAL.new()
		add_child(portal)
		portal.global_position = site
		portal.configure(entrance_id, chunk_key, entrance_quality)
		portal.selected.connect(_on_portal_selected)
		entrances[entrance_id] = portal
		owned.append(entrance_id)
	chunks[chunk_key] = {"quality": quality, "portals": owned}

func unregister_chunk(chunk_key: String) -> void:
	if not chunks.has(chunk_key):
		return
	var state: Dictionary = chunks[chunk_key]
	for id in state.get("portals", []):
		_remove_entrance(str(id))
	chunks.erase(chunk_key)

func _register_demo_chunks() -> void:
	# The current 46x46 starter map has no chunk streamer yet; show one
	# deterministic example per tier. The procedural v4 branch disables this.
	var examples: Array = [
		["preview_common", 0, Vector3(-18, 0, -18)],
		["preview_uncommon", 1, Vector3(18, 0, -18)],
		["preview_rare", 2, Vector3(-18, 0, 18)],
		["preview_epic", 3, Vector3(18, 0, 18)],
		["preview_legendary", 4, Vector3(0, 0, -19)]
	]
	for entry in examples:
		var site: Vector3 = entry[2]
		register_chunk(str(entry[0]), Rect2(Vector2(site.x - 7.0, site.z - 7.0), Vector2(14, 14)), int(entry[1]), [site], true)

func _physics_process(_delta: float) -> void:
	if hero == null or not is_instance_valid(hero):
		return
	if dimmer.visible:
		return
	if active_instance != null:
		if not is_instance_valid(active_instance):
			active_instance = null
			return
		# Existing Outpost death handling returns the character to (0,0,0).
		# If that happens mid-dungeon, release the instance cleanly.
		if hero.global_position.distance_to(active_instance.global_position) > 350.0:
			_exit_current(false, true)
			return
		_update_dungeon_action()
	else:
		_update_overworld_action()

func _update_overworld_action() -> void:
	leave_button.visible = false
	progress_label.visible = false
	if approaching_portal != null:
		if not is_instance_valid(approaching_portal):
			approaching_portal = null
			hero.stop_interaction_move()
		else:
			var range_to_target: float = _flat_distance(hero.global_position, approaching_portal.global_position)
			if range_to_target <= INTERACTION_RADIUS:
				var arrived: Area3D = approaching_portal
				approaching_portal = null
				hero.stop_interaction_move()
				_prompt_to_enter(arrived)
				return
			if not hero.interaction_moving:
				approaching_portal = null
	nearest_portal = null
	var closest: float = INTERACTION_RADIUS
	for value in entrances.values():
		if not is_instance_valid(value):
			continue
		var portal: Area3D = value as Area3D
		var distance: float = _flat_distance(hero.global_position, portal.global_position)
		if distance < closest:
			closest = distance
			nearest_portal = portal
	action_button.visible = nearest_portal != null
	if nearest_portal != null:
		action_button.text = "ENTER %s" % RARITY.quality_name(int(nearest_portal.get("quality"))).to_upper()
		action_button.add_theme_stylebox_override("normal", THEME.style(THEME.SURFACE, RARITY.color(int(nearest_portal.get("quality")))))

func _update_dungeon_action() -> void:
	leave_button.visible = true
	progress_label.visible = true
	var remaining: int = int(active_instance.guards_remaining)
	var title: String = RARITY.quality_name(int(active_info.get("quality", 0))).to_upper()
	var current: int = int(active_instance.current_floor)
	var total: int = int(active_instance.floor_count)
	progress_label.text = "%s  •  FLOOR %d/%d  •  %s  •  %d GUARD(S)" % [title, current, total, str(active_instance.layout.get("pattern", "")).to_upper(), remaining]
	progress_label.add_theme_color_override("font_color", RARITY.color(int(active_info.get("quality", 0))))
	if minimap != null and minimap.instance != active_instance:
		minimap.setup(active_instance)
	if minimap != null:
		minimap.visible = true
	var distance: float = _flat_distance(hero.global_position, active_instance.chest_world_position())
	if approaching_chest:
		if distance <= INTERACTION_RADIUS:
			approaching_chest = false
			hero.stop_interaction_move()
			_claim_chest()
		elif not hero.interaction_moving:
			approaching_chest = false
	var nearby_bonus: int = active_instance.nearest_bonus(hero.global_position, INTERACTION_RADIUS)
	action_button.visible = distance <= INTERACTION_RADIUS or nearby_bonus >= 0
	if nearby_bonus >= 0 and distance > INTERACTION_RADIUS:
		active_bonus_id = nearby_bonus
		action_button.text = "OPEN BONUS CACHE"
		action_button.disabled = false
	elif distance <= INTERACTION_RADIUS:
		active_bonus_id = -1
		if active_instance.current_floor < active_instance.floor_count:
			action_button.text = "STAIRS  •  NEXT FLOOR" if active_instance.can_advance_floor() else "STAIRS LOCKED"
			action_button.disabled = not active_instance.can_advance_floor()
		else:
			action_button.text = "OPEN FINAL CHEST" if active_instance.can_claim_chest() else "FINAL CHEST LOCKED"
			action_button.disabled = not active_instance.can_claim_chest()
	else:
		active_bonus_id = -1
		action_button.disabled = false


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _on_portal_selected(portal: Area3D) -> void:
	if active_instance != null or dimmer.visible or hero == null:
		return
	if game.menu != null and game.menu.visible:
		return
	var dist: float = _flat_distance(hero.global_position, portal.global_position)
	if dist <= INTERACTION_RADIUS:
		_prompt_to_enter(portal)
	else:
		approaching_portal = portal
		hero.move_to_interaction(portal.global_position)
		if game.hud != null:
			game.hud.toast("Approaching %s dungeon..." % RARITY.quality_name(int(portal.get("quality"))))

func _on_action_pressed() -> void:
	if active_instance != null:
		if active_bonus_id >= 0:
			_claim_bonus(active_bonus_id)
		else:
			_claim_chest()
	elif nearest_portal != null and is_instance_valid(nearest_portal):
		_prompt_to_enter(nearest_portal)

func _prompt_to_enter(portal: Area3D) -> void:
	if portal == null or not is_instance_valid(portal):
		return
	if active_instance != null or completed_ids.has(str(portal.get("entrance_id"))):
		return
	chosen_portal = portal
	var tier: int = int(portal.get("quality"))
	var accent: Color = RARITY.color(tier)
	dialog_title.text = "%s  •  %s" % [RARITY.quality_name(tier).to_upper(), str(portal.get("dungeon_title"))]
	dialog_title.add_theme_color_override("font_color", accent)
	var profile: Dictionary = LAYOUT.profile(str(portal.get("entrance_id")), tier)
	var floors: int = int(profile.get("floors", 1))
	var info: Dictionary = LAYOUT.settings()
	var room_ranges: Array = info.get("room_ranges", [])
	var room_range: Array = room_ranges[tier]
	var multiplier: float = pow(float(profile.get("reward_multiplier", 1.3)), floors - 1)
	dialog_message.text = "%d floor(s) • %d–%d rooms/floor\nFinal treasure multiplier: x%.2f\nDefeat guardians, advance through stairs, claim final reward.\nCompleted portals vanish; abandoned ones remain." % [floors, int(room_range[0]), int(room_range[1]), multiplier]
	confirm_button.add_theme_stylebox_override("normal", THEME.style(THEME.SURFACE, accent))
	dimmer.visible = true
	action_button.visible = false
	hero.stop_interaction_move()
	hero.interaction_locked = true

func _cancel_dialog() -> void:
	dimmer.visible = false
	chosen_portal = null
	if hero != null:
		hero.interaction_locked = false

func _enter_confirmed() -> void:
	if chosen_portal == null or not is_instance_valid(chosen_portal):
		_cancel_dialog()
		return
	var portal: Area3D = chosen_portal
	_cancel_dialog()
	if hero == null:
		return
	approaching_portal = null
	approaching_chest = false
	return_position = hero.global_position
	active_info = {
		"id": str(portal.get("entrance_id")),
		"quality": int(portal.get("quality")),
		"origin": portal.global_position
	}
	run_number += 1
	var dungeon = INSTANCE.new()
	add_child(dungeon)
	# A new isolated cell, out of reach of the current overworld geometry.
	dungeon.position = Vector3(1800.0 + float(run_number % 30) * 65.0, 0.0, 1800.0)
	var checkpoint: int = int(floor_checkpoints.get(str(active_info["id"]), 1))
	dungeon.setup(str(active_info["id"]), int(active_info["quality"]), hero, checkpoint)
	dungeon.chest_selected.connect(_on_chest_selected)
	dungeon.stairs_selected.connect(_on_stairs_selected)
	dungeon.bonus_selected.connect(_on_bonus_selected)
	dungeon.floor_changed.connect(_on_floor_changed)
	dungeon.completed.connect(_on_dungeon_completed)
	active_instance = dungeon
	if minimap != null:
		minimap.setup(dungeon)
	hero.global_position = dungeon.hero_spawn_point()
	hero.velocity = Vector3.ZERO
	action_button.visible = false
	if game.hud != null:
		game.hud.toast("Dungeon entered. Defeat guardians and open the treasure chest.")

func _on_chest_selected(instance: Node3D) -> void:
	if instance != active_instance or hero == null or dimmer.visible:
		return
	if not active_instance.can_claim_chest() and not active_instance.can_advance_floor():
		if game.hud != null:
			game.hud.toast("%d guardian(s) remain before the exit unlocks." % int(active_instance.guards_remaining))
		return
	if _flat_distance(hero.global_position, active_instance.chest_world_position()) <= INTERACTION_RADIUS:
		_claim_chest()
	else:
		approaching_chest = true
		hero.move_to_interaction(active_instance.chest_world_position())

func _claim_chest() -> void:
	if active_instance == null or not is_instance_valid(active_instance):
		return
	if not active_instance.can_claim_chest():
		return
	if active_instance.current_floor < active_instance.floor_count:
		active_instance.advance_floor()
	else:
		active_instance.claim_chest()

func _on_stairs_selected(instance: Node3D) -> void:
	if instance != active_instance or hero == null:
		return
	if _flat_distance(hero.global_position, active_instance.chest_world_position()) <= INTERACTION_RADIUS:
		_claim_chest()
	elif active_instance.can_advance_floor():
		approaching_chest = true
		hero.move_to_interaction(active_instance.chest_world_position())

func _on_floor_changed(instance: Node3D, floor: int, floors: int) -> void:
	if instance != active_instance:
		return
	floor_checkpoints[str(active_info.get("id", ""))] = floor
	_save_clears()
	if minimap != null:
		minimap.setup(instance)
	if game.hud != null:
		game.hud.toast("Floor %d/%d — enemies grow stronger, rewards improve." % [floor, floors])

func _on_bonus_selected(instance: Node3D, id: int) -> void:
	if instance != active_instance or hero == null:
		return
	_claim_bonus(id)

func _claim_bonus(id: int) -> void:
	if active_instance == null or not is_instance_valid(active_instance):
		return
	var reward: Dictionary = active_instance.claim_bonus(id)
	if reward.is_empty():
		return
	_apply_reward(reward)
	if game.hud != null:
		game.hud.toast("Bonus cache: +%d coins and crafting supplies" % int(reward.get("coins", 0)))

func _on_dungeon_completed(instance: Node3D, reward: Dictionary) -> void:
	if instance != active_instance or game == null:
		return
	var tier: int = int(active_info.get("quality", 0))
	_apply_reward(reward)
	_exit_current(true, false)
	if game.hud != null:
		game.hud.toast("%s cleared! +%d coins • %d XP • new crafting loot" % [RARITY.quality_name(tier), int(reward.get("coins", 0)), int(reward.get("xp", 0))])

func _apply_reward(reward: Dictionary) -> void:
	if game == null:
		return
	var pocket: Dictionary = game.inventory
	pocket["coins"] = int(pocket.get("coins", 0)) + maxi(0, int(reward.get("coins", 0)))
	game.experience += maxi(0, int(reward.get("xp", 0)))
	var materials: Dictionary = reward.get("materials", {})
	for item_id in materials:
		var key: String = str(item_id)
		pocket[key] = int(pocket.get(key, 0)) + maxi(0, int(materials[item_id]))
	for book in reward.get("books", []):
		var id: String = str(book)
		if id != "":
			pocket[id] = int(pocket.get(id, 0)) + 1
	# Retain compatibility if an older reward object is supplied by an extension.
	var legacy: String = str(reward.get("item", ""))
	if legacy != "":
		pocket[legacy] = int(pocket.get(legacy, 0)) + maxi(0, int(reward.get("amount", 0)))
	game._save()
	game._refresh_menu()


func _exit_current(succeeded: bool, due_to_death: bool = false) -> void:
	if active_instance == null:
		return
	var cleared_id: String = str(active_info.get("id", ""))
	if succeeded:
		completed_ids[cleared_id] = true
		floor_checkpoints.erase(cleared_id)
		_save_clears()
		_remove_entrance(cleared_id)
	hero.stop_interaction_move()
	hero.interaction_locked = false
	if not due_to_death:
		hero.global_position = return_position
	hero.velocity = Vector3.ZERO
	if is_instance_valid(active_instance):
		active_instance.queue_free()
	active_instance = null
	chosen_portal = null
	approaching_chest = false
	leave_button.visible = false
	progress_label.visible = false
	if minimap != null:
		minimap.setup(null)
	action_button.visible = false
	action_button.disabled = false
	active_bonus_id = -1
	if due_to_death and game.hud != null:
		game.hud.toast("Dungeon attempt failed; entrance remains available.")
	active_info = {}

func _leave_pressed() -> void:
	if active_instance != null:
		_exit_current(false, false)
		if game.hud != null:
			game.hud.toast("Left dungeon. Entrance is still available.")

func _remove_entrance(id: String) -> void:
	if not entrances.has(id):
		return
	var portal = entrances[id]
	if approaching_portal == portal:
		approaching_portal = null
		if hero != null:
			hero.stop_interaction_move()
	if nearest_portal == portal:
		nearest_portal = null
	if chosen_portal == portal:
		_cancel_dialog()
	if is_instance_valid(portal):
		portal.queue_free()
	entrances.erase(id)

func _load_clears() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not (parsed is Dictionary):
		return
	var saved_progress: Variant = parsed.get("checkpoints", {})
	if saved_progress is Dictionary:
		floor_checkpoints = saved_progress.duplicate()
	var saved: Variant = parsed.get("completed", [])
	if saved is Array:
		for entry in saved:
			completed_ids[str(entry)] = true

func _save_clears() -> void:
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"version": 2, "completed": completed_ids.keys(), "checkpoints": floor_checkpoints}))
		file.close()

func _build_interface() -> void:
	interface_layer = CanvasLayer.new()
	interface_layer.layer = 22
	add_child(interface_layer)
	var screen := Control.new()
	screen.name = "DungeonUI"
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	interface_layer.add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	action_button = THEME.button("ENTER DUNGEON", "door_front", RARITY.color(RARITY.RARE))
	screen.add_child(action_button)
	_layout(action_button, 0.655, 0.155, 0.960, 0.260)
	action_button.visible = false
	action_button.pressed.connect(_on_action_pressed)
	leave_button = THEME.button("LEAVE", "arrow_back", Color("b07b70"))
	screen.add_child(leave_button)
	_layout(leave_button, 0.815, 0.280, 0.964, 0.380)
	leave_button.visible = false
	leave_button.pressed.connect(_leave_pressed)
	progress_label = THEME.label("", 19)
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen.add_child(progress_label)
	_layout(progress_label, 0.240, 0.195, 0.625, 0.26)
	progress_label.visible = false
	minimap = MINIMAP.new()
	minimap.tooltip_text = "Dungeon map: pale rooms, green bonus caches, gold stairs, orange boss"
	screen.add_child(minimap)
	_layout(minimap, 0.812, 0.415, 0.966, 0.704)
	minimap.visible = false

	dimmer = ColorRect.new()
	dimmer.color = Color(0.01, 0.02, 0.04, 0.77)
	dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	screen.add_child(dimmer)
	dimmer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dimmer.visible = false
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", THEME.style(THEME.BACKDROP, THEME.ACCENT, 15))
	dimmer.add_child(panel)
	_layout(panel, 0.235, 0.23, 0.765, 0.79)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	panel.add_child(stack)
	dialog_title = THEME.label("DUNGEON", 27)
	dialog_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(dialog_title)
	dialog_message = THEME.label("Enter dungeon?", 20)
	dialog_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(dialog_message)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 24)
	stack.add_child(actions)
	confirm_button = THEME.button("YES • ENTER", "check_circle", RARITY.color(RARITY.RARE))
	actions.add_child(confirm_button)
	confirm_button.pressed.connect(_enter_confirmed)
	var decline := THEME.button("CANCEL", "cancel", Color("b9a29b"))
	actions.add_child(decline)
	decline.pressed.connect(_cancel_dialog)

func _layout(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom
	control.offset_left = 0.0
	control.offset_top = 0.0
	control.offset_right = 0.0
	control.offset_bottom = 0.0

func _unhandled_input(event: InputEvent) -> void:
	if dimmer != null and dimmer.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_dialog()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_clears()
