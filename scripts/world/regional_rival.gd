extends RefCounted
## Stable seed/territory/spawn-slot identities. Only actual player defeats
## promote a named NPC; its death ends that career and creates a successor.
const MAX_RANK := 4
const FOLLOWERS := [0,1,2,4,6]
const TITLES := ["","Veteran","Captain","Warlord","Overlord"]
const POWERS := ["","Hardy","Swift","Relentless","Overwhelming"]
const GOBLIN_NAMES := ["Grukk","Snagg","Ruzg","Mogg","Krag","Vrekk","Zib","Gorr"]
const BONE_NAMES := ["Durn","Khar","Thrain","Morv","Varr","Drel","Skarn","Borr"]
const EPITHETS := ["the Grim","the Iron","the Bold","the Hollow","the Scarred","the Unbroken","the Ruthless","the Wanderer"]

static func fresh(generation: int = 0) -> Dictionary:
	return {"generation":generation,"victories":0,"rank":0,"defeated":0}

static func sanitize(raw: Variant) -> Dictionary:
	var result := fresh()
	if not raw is Dictionary: return result
	for key in ["generation","victories","defeated"]:
		var v: Variant = raw.get(key,0)
		if typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v)):
			result[key]=clampi(int(v),0,1000000)
	result["rank"]=mini(MAX_RANK,int(result["victories"]))
	return result

static func promote(record: Dictionary) -> bool:
	var before: int = int(record["rank"])
	record["victories"]=mini(1000000,int(record["victories"])+1)
	record["rank"]=mini(MAX_RANK,int(record["victories"]))
	return int(record["rank"])>before

static func retire(record: Dictionary) -> void:
	record["generation"]=mini(1000000,int(record["generation"])+1)
	record["defeated"]=mini(1000000,int(record["defeated"])+1)
	record["rank"]=0
	record["victories"]=0

static func name_for(id: String,record: Dictionary,kind: String,ordinary: String) -> String:
	var rank: int = int(record["rank"])
	if rank==0: return ordinary
	var code := hash(id+":"+str(record["generation"]))
	var pool: Array = GOBLIN_NAMES if kind=="goblin" else BONE_NAMES
	return "%s %s · %s" % [pool[posmod(code,pool.size())],EPITHETS[posmod(code/8,EPITHETS.size())],TITLES[rank]]

static func follower_count(rank: int) -> int:
	return FOLLOWERS[clampi(rank,0,MAX_RANK)]

static func power(rank: int) -> String:
	return POWERS[clampi(rank,0,MAX_RANK)]
