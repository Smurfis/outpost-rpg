extends Control
## World Preview: a single pooled screen-space canvas, with cutaway-aware
## visibility sampling and bounded nameplate density. Never consumes input.
const RARITY = preload("res://scripts/dungeons/dungeon_rarity.gd")
const RANGE := 12.0
const BOSS_RANGE := 18.0
const LIMIT := 8
var game: Node3D
var actors: Array[Node3D] = []
var boss: Node3D
var age := 1.0
var drawn_count := 0

func _ready() -> void:
	name="CombatNameplates"
	mouse_filter=Control.MOUSE_FILTER_IGNORE

func configure(ref: Node3D) -> void:
	game=ref

func _blocked_ui() -> bool:
	return not is_instance_valid(game) or game.hero==null or game.camera==null or (game.controls!=null and game.controls.modal_open())

func _physics_process(delta: float) -> void:
	age+=delta
	if age<0.125: return
	age=0.0
	refresh()

func _process(_delta: float) -> void:
	queue_redraw()

func friendly(actor: Node3D) -> bool:
	return actor.get_meta("world_kind","")=="npc" or actor.is_in_group("friendly_npcs")

func same_floor(actor: Node3D) -> bool:
	var a: Vector3 = game.hero.global_position
	var b: Vector3 = actor.global_position
	if absf(a.y-b.y)>3.0: return false
	if game.terrain_surface==null: return true
	var remote = game.terrain_surface.get("archipelago")
	if remote==null or remote.terrain==null: return true
	var terrain = remote.terrain
	var af: int = terrain.caves.floor_at(floori(a.x),floori(a.z))
	var bf: int = terrain.caves.floor_at(floori(b.x),floori(b.z))
	var ac: bool = af!=-99999 and absf(a.y-af)<1.8 and a.y<terrain.height_at(floori(a.x),floori(a.z))-0.8
	var bc: bool = bf!=-99999 and absf(b.y-bf)<1.8 and b.y<terrain.height_at(floori(b.x),floori(b.z))-0.8
	return ac==bc

func visible_actor(actor: Node3D,limit: float) -> bool:
	if not is_instance_valid(actor) or not actor.is_inside_tree() or not actor.is_visible_in_tree(): return false
	if actor!=game.hero and not friendly(actor) and not game.target_available(actor): return false
	if actor.global_position.distance_to(game.hero.global_position)>limit or not same_floor(actor): return false
	var point := actor.global_position+Vector3.UP*1.25
	if game.camera.is_position_behind(point): return false
	var screen: Vector2 = game.camera.unproject_position(point)
	if not Rect2(Vector2.ZERO,get_viewport_rect().size).has_point(screen): return false
	var origin: Vector3 = game.camera.project_ray_origin(screen)
	var direction: Vector3 = game.camera.project_ray_normal(screen)
	var excluded: Array[RID] = []
	if game.hero is CollisionObject3D: excluded.append(game.hero.get_rid())
	if actor is CollisionObject3D: excluded.append(actor.get_rid())
	var mask := 1
	var remote = game.terrain_surface.get("archipelago") if game.terrain_surface!=null else null
	if remote!=null and remote.section_active:
		excluded.append_array(remote.section_excluded)
		mask|=remote.SECTION_PICK
	for i in range(16):
		var query := PhysicsRayQueryParameters3D.create(origin,point,mask,excluded)
		var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty(): return true
		var body = hit.get("collider")
		if body is CollisionObject3D and (body.get_meta("building_cutaway_hidden",false) or body.get_meta("dungeon_cutaway_hidden",false)):
			excluded.append(body.get_rid())
			continue
		if remote!=null and remote.cutaway_hides_hit(hit):
			origin=Vector3(hit.position)+direction*0.13
			if (point-origin).dot(direction)<=0.0: return true
			continue
		return false
	return false

func is_boss(actor: Node3D) -> bool:
	return actor.name=="DungeonBoss" or actor.is_in_group("gm_overlords") or (actor.has_method("credit_player_defeat") and not str(actor.get("rival_id")).is_empty() and int(actor.get("quality"))==4)

func refresh() -> void:
	actors.clear()
	boss=null
	if _blocked_ui(): return
	var candidates: Array[Node3D] = []
	var focus: Node3D = game.target_for_hud()
	for actor in get_tree().get_nodes_in_group("enemies"):
		if not actor is Node3D or not game.target_available(actor): continue
		if actor.global_position.distance_to(game.hero.global_position)>BOSS_RANGE: continue
		candidates.append(actor)
	for group in ["world_interactables","friendly_npcs"]:
		for actor in get_tree().get_nodes_in_group(group):
			if actor is Node3D and friendly(actor) and not candidates.has(actor) and actor.global_position.distance_to(game.hero.global_position)<=RANGE:
				candidates.append(actor)
	candidates.sort_custom(func(a: Node3D,b: Node3D) -> bool:
		if a==focus: return b!=focus
		if b==focus: return false
		return a.global_position.distance_squared_to(game.hero.global_position)<b.global_position.distance_squared_to(game.hero.global_position))
	for actor in candidates.slice(0,16):
		var major := is_boss(actor)
		if not visible_actor(actor,BOSS_RANGE if major else RANGE): continue
		if major and boss==null: boss=actor
		if actors.size()<LIMIT: actors.append(actor)

func _meter(rect: Rect2,fraction: float,tint: Color) -> void:
	draw_rect(rect.grow(1.0),Color("#786e65"))
	draw_rect(rect,Color("#19151a"))
	var filled := Rect2(rect.position+Vector2.ONE,Vector2(maxf(0.0,(rect.size.x-2.0)*clampf(fraction,0.0,1.0)),rect.size.y-2.0))
	if filled.size.x>0.0:
		draw_rect(filled,tint)
		draw_rect(Rect2(filled.position,Vector2(filled.size.x,1)),tint.lightened(0.25))

func _caption(font: Font,at: Vector2,caption: String,px: int,tint: Color) -> void:
	var w := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,px).x
	var origin := at-Vector2(w*0.5,0)
	draw_string_outline(font,origin,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,px,4,Color("#151218"))
	draw_string(font,origin,caption,HORIZONTAL_ALIGNMENT_LEFT,-1,px,tint)

func _stars(at: Vector2,rank: int,s: float) -> void:
	var font: Font = ThemeDB.fallback_font
	for i in range(5):
		_caption(font,at+Vector2((i-2)*12.0*s,0),"★",roundi(12*s),RARITY.color(rank) if i<=rank else Color("#655d5b"))

func _draw() -> void:
	drawn_count=0
	if _blocked_ui(): return
	var font: Font = ThemeDB.fallback_font
	var s := clampf(get_viewport_rect().size.y/720.0,0.8,1.25)
	var occupied: Array[Rect2] = []
	var player: Node3D = game.hero
	var all: Array[Node3D] = [player]
	all.append_array(actors)
	for actor in all:
		if not is_instance_valid(actor) or not actor.is_visible_in_tree(): continue
		var own := actor==player
		var ally := not own and friendly(actor)
		if not own and (not ally and not game.target_available(actor)): continue
		if not own and (actor.global_position.distance_to(player.global_position)>(BOSS_RANGE if is_boss(actor) else RANGE) or not same_floor(actor)): continue
		var at := actor.global_position+Vector3.UP*(2.85 if ally else 2.35 if own or actor.is_in_group("dungeon_guardians") else 1.6)
		if game.camera.is_position_behind(at): continue
		var p: Vector2 = game.camera.unproject_position(at)
		if not Rect2(Vector2.ZERO,get_viewport_rect().size).grow(-8).has_point(p): continue
		var data: Dictionary = {} if own or ally else game.target_frame_data(actor)
		if not own and not ally and data.is_empty(): continue
		var caption := "" if own else str(actor.get_meta("display_name",actor.name)) if ally else str(data["name"])
		var rank := int(actor.get("quality")) if actor.is_in_group("dungeon_guardians") else 0
		var ranked := not own and not ally and rank>0
		var width := 86.0*s
		var label_w := maxf(width,font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,roundi(13*s)).x)
		var rect := Rect2(p-Vector2(label_w/2,37*s),Vector2(label_w,40*s))
		var overlap := false
		for old in occupied:
			if old.intersects(rect): overlap=true
		if overlap: continue
		occupied.append(rect)
		var tint := Color("#86d6a1") if ally else Color("#f1e9d8") if own else data.get("name_color",Color("#f1e9d8")) as Color
		if not caption.is_empty(): _caption(font,p-Vector2(0,18*s if ranked else 9*s),caption,roundi(13*s),tint)
		if ranked: _stars(p-Vector2(0,6*s),rank,s)
		var hp: Variant = player.health if own else actor.get("hp") if ally else data.get("hp")
		var maximum: Variant = 100.0 if own else actor.get("max_hp") if ally else data.get("max_hp")
		if (hp is float or hp is int) and (maximum is float or maximum is int) and float(maximum)>0:
			_meter(Rect2(p-Vector2(width/2,0),Vector2(width,7*s)),float(hp)/float(maximum),Color("#c32430"))
		var mana: Variant = game.mana if own else actor.get("mana")
		var mana_max: Variant = game.mana_limit() if own else actor.get("max_mana")
		if (mana is float or mana is int) and (mana_max is float or mana_max is int) and float(mana_max)>0:
			_meter(Rect2(p+Vector2(-width/2,9*s),Vector2(width,4*s)),float(mana)/float(mana_max),Color("#387ddb"))
		drawn_count+=1
