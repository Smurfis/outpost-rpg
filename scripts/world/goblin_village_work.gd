extends RefCounted
## Bounded work simulation in active gameplay time, not real-world/offline time.
## Fixed storage identities survive streaming and experimental layout rerolls.
const ROUND_SECONDS := 75.0
const RESPAWN_SECONDS := 120.0
const MAX_PER_ITEM := 24
const GOODS := ["wood","stone","fiber","coal","iron"]

static func sanitize(raw: Variant) -> Dictionary:
	var result := {"work":0.0,"rest":0.0,"round":0,"stock":{}}
	if not raw is Dictionary: return result
	for key in ["work","rest","round"]:
		var v: Variant = raw.get(key,0)
		if typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v)):
			result[key]=clampf(float(v),0.0,ROUND_SECONDS if key=="work" else RESPAWN_SECONDS if key=="rest" else 1000000.0)
	result["round"]=int(result["round"])
	var stock: Variant = raw.get("stock",{})
	if stock is Dictionary:
		for id in GOODS:
			var v: Variant = stock.get(id,0)
			if typeof(v) in [TYPE_INT,TYPE_FLOAT] and is_finite(float(v)) and int(v)>0:
				result["stock"][id]=clampi(int(v),0,MAX_PER_ITEM)
	return result

static func advance(record: Dictionary,seconds: float,seed_value: int,worker: int) -> bool:
	if seconds<=0.0: return false
	if float(record["rest"])>0.0:
		record["rest"]=maxf(0.0,float(record["rest"])-seconds)
		return is_zero_approx(float(record["rest"]))
	record["work"]=float(record["work"])+seconds
	if float(record["work"])<ROUND_SECONDS: return false
	record["work"]=fmod(float(record["work"]),ROUND_SECONDS)
	record["round"]=posmod(int(record["round"])+1,1000000)
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value ^ (worker*3571) ^ (int(record["round"])*7919)
	var stock: Dictionary = record["stock"]
	var id: String = GOODS[rng.randi_range(0,2)] if rng.randf()<0.85 else GOODS[rng.randi_range(3,4)]
	stock[id]=mini(MAX_PER_ITEM,int(stock.get(id,0))+rng.randi_range(2,5))
	return true

static func defeat(record: Dictionary) -> void:
	record["work"]=0.0
	record["rest"]=RESPAWN_SECONDS

static func route_point(path: Array,work: float) -> Vector2:
	if path.is_empty(): return Vector2.ZERO
	var fraction := clampf(work/ROUND_SECONDS,0.0,1.0)
	# 40% outbound, 20% collecting, 40% return.
	var travel := minf(fraction/0.4,(1.0-fraction)/0.4)
	var index := clampf(travel,0.0,1.0)*float(path.size()-1)
	var a := floori(index)
	var b := mini(a+1,path.size()-1)
	return Vector2(path[a]).lerp(Vector2(path[b]),index-float(a))+Vector2(0.5,0.5)
