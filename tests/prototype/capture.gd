extends SceneTree
const SCENE = preload("chamber.tscn")
const OUT := "res://artifacts/cave_render/voxel-section/"
var failed := false

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		failed = true

func run() -> void:
	root.size = Vector2i(1280,720)
	var world := SCENE.instantiate()
	root.add_child(world)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var poses := [["01-roof",4.5,-45,false],["02-section",4.5,-45,true],["03-rotated",4.5,45,true],["04-second-room",11.5,45,true]]
	for pose in poses:
		var at := Vector3(pose[1],0,5.5)
		if pose[0] == "04-second-room":
			world.pose(Vector3(9.5,0,5.5),pose[2],true)
			check(world.room == 0,"Doorway must retain the last occupied room")
		world.pose(at,pose[2],pose[3])
		await physics_frame
		await physics_frame
		var target := at + Vector3(0.6,0,0.5)
		var screen: Vector2 = world.camera.unproject_position(target)
		var hit: Dictionary = world.pick(screen)
		var physical: Dictionary = world.pick(screen,1)
		check(not physical.is_empty() and physical.position.y > 3.9,"Physical roof missing")
		if pose[3]:
			check(world.section_faces > 0,"Expected newly exposed voxel faces")
			check(not hit.is_empty() and hit.position.distance_to(target)<0.03,"Visible floor pick failed: "+str(hit))
		else:
			check(not hit.is_empty() and hit.position.y > 3.9,"Intact roof pick failed")
		var count: int = world.volume.meshes_built
		world.refresh()
		check(world.volume.meshes_built == count,"Stationary section rebuilt")
		await RenderingServer.frame_post_draw
		check(root.get_texture().get_image().save_png(OUT + pose[0] + ".png")==OK,"PNG write failed")
		print(pose[0]," room=",world.room," new faces=",world.section_faces," picked=",hit.get("position"))
	var previous_room := Vector3(4.5,5,5.5)
	var closed_hit: Dictionary = world.pick(world.camera.unproject_position(previous_room))
	check(not closed_hit.is_empty() and closed_hit.position.distance_to(previous_room)<0.03,"Previous roof did not close")
	var built: int = world.volume.meshes_built
	world.pose(Vector3(4.5,0,5.5),-45,true)
	check(world.volume.meshes_built == built,"Revisiting a section missed cache")
	world.queue_free()
	await process_frame
	quit(1 if failed else 0)

