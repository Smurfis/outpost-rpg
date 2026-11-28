extends "res://scripts/world/mine_goblin.gd"
## Regional encounter, separate from persistent mine/dungeon objectives.
const RIVAL = preload("res://scripts/world/regional_rival.gd")
var rival_game: Node
var rival_id := ""
var rival_record: Dictionary = {}
var rival_kind := ""
var rival_ordinary := ""
var rival_base_tier := 0
var rival_generation := -1
var rival_follower := false
var underground_guard := true
var skeletal_guard := false
var home := Vector3.ZERO

func _same_level() -> bool:
	if hero==null: return false
	var p: Vector3 = hero.global_position
	var city = terrain.skeletal_city if skeletal_guard else terrain.goblin_city
	if city==null or not city.contains(Vector2i(floori(p.x),floori(p.z))): return false
	var cell := Vector2i(floori(p.x),floori(p.z))
	var in_cave: bool = city.floors.has(cell) and absf(p.y-float(city.floors.get(cell,-99999)))<1.75 and p.y<terrain.height_at(cell.x,cell.y)-1.0
	return in_cave==underground_guard and absf(p.y-global_position.y)<2.0

func melee_visible() -> bool:
	if not _same_level(): return false
	var ray := PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,hero.global_position+Vector3.UP,1,[get_rid(),hero.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func pursuit_direction(to_player: Vector3) -> Vector3:
	if not _same_level() or global_position.distance_to(home)>12.0: return Vector3.ZERO
	if underground_guard: return super.pursuit_direction(to_player)
	return to_player.normalized()

func bind_rival(game: Node,id: String,kind: String,ordinary: String,base_tier: int) -> void:
	rival_game=game
	rival_id=id
	rival_kind=kind
	rival_ordinary=ordinary
	rival_base_tier=base_tier
	if not game.regional_rivals.has(id):
		game.regional_rivals[id]=RIVAL.fresh()
	rival_record=game.regional_rivals[id]
	rival_generation=int(rival_record["generation"])
	_apply_rival_rank(true)
	slain.connect(_retire_rival,CONNECT_ONE_SHOT)

func _apply_rival_rank(full_health: bool) -> void:
	var rank: int = int(rival_record["rank"])
	quality=rank
	max_hp=(24.0+15.0*maxi(rank,rival_base_tier))*(1.0+0.18*rank)
	if full_health: hp=max_hp
	damage_multiplier=1.0+0.12*rank+ (0.12 if rank>=4 else 0.0)
	speed_multiplier=1.0+(0.18 if rank>=2 else 0.0)
	display_name=RIVAL.name_for(rival_id,rival_record,rival_kind,rival_ordinary)
	affix_details=RIVAL.power(rank)
	if rank>=3: heavy_attack_cooldown=minf(heavy_attack_cooldown,2.5)

func strike_player(amount: float) -> void:
	if rival_id.is_empty():
		super.strike_player(amount)
	else:
		hero.take_hit(amount,global_position,self)

func credit_player_defeat() -> String:
	if not alive or rival_id.is_empty() or not is_instance_valid(rival_game) or int(rival_record.get("generation",-1))!=rival_generation: return ""
	var promoted := RIVAL.promote(rival_record)
	_apply_rival_rank(true)
	if promoted:
		return "%s promoted to %s!" % [display_name, RIVAL.TITLES[int(rival_record["rank"])]]
	return "%s defeated you again." % display_name

func _begin_heavy_attack(to_player: Vector3) -> void:
	super._begin_heavy_attack(to_player)
	if not rival_record.is_empty() and int(rival_record["rank"])>=3:
		heavy_attack_cooldown=minf(heavy_attack_cooldown,3.2)

func _retire_rival() -> void:
	if not is_instance_valid(rival_game) or int(rival_record.get("generation",-1))!=rival_generation: return
	if int(rival_record["rank"])>0:
		var retired_name := display_name
		var rank: int = int(rival_record["rank"])
		RIVAL.retire(rival_record)
		rival_game.grant_item("coins",8*rank,true)
		rival_game.gain_experience(20*rank)
		if rival_game.hud!=null: rival_game.hud.record_combat_event(retired_name+" defeated")
	else:
		RIVAL.retire(rival_record)
	rival_game._save()
