extends RefCounted
## Edit overlay: generated base remains immutable; only differences are serialized.
const Prefab = preload("res://scripts/world/city_lab_prefab.gd")
const Mesher = preload("res://scripts/world/city_lab_mesher.gd")
const MAX_EDITS := 50000
const MAX_FILE_BYTES := 4000000
const SCHEMA := 1
const GENERATOR := "city-lab-v2"
var prefab := Prefab.new()
var mesher := Mesher.new()
var baseline: Dictionary = {}
var changes: Dictionary = {}
var undo_stack: Array[Dictionary] = []

func reset(blocks: Dictionary) -> void:
	baseline = blocks.duplicate()
	changes.clear()
	undo_stack.clear()

func _value(blocks: Dictionary, p: Vector3i) -> int:
	return int(blocks.get(p,-1))

func _put(blocks: Dictionary, p: Vector3i, material: int) -> void:
	if material == -1: blocks.erase(p)
	else: blocks[p] = material

func _record(p: Vector3i, value: int) -> void:
	if _value(baseline,p) == value: changes.erase(p)
	else: changes[p] = value

func valid_patch(patch: Dictionary) -> bool:
	if patch.is_empty() or patch.size() > MAX_EDITS: return false
	for p in patch:
		if not p is Vector3i or not prefab.inside(p): return false
		var material: Variant = patch[p]
		if not material is int or material < -1 or material > 6: return false
	return true

func apply(plan, patch: Dictionary, player_cell: Vector2i, remember: bool = true) -> bool:
	if not valid_patch(patch): return false
	var inverse: Dictionary = {}
	var count := changes.size()
	for p: Vector3i in patch:
		var previous := _value(plan.blocks,p)
		var next: int = patch[p]
		if previous == next: continue
		inverse[p] = previous
		if changes.has(p): count -= 1
		if _value(baseline,p) != next: count += 1
	if inverse.is_empty() or count > MAX_EDITS: return false
	for p: Vector3i in inverse: _put(plan.blocks,p,int(patch[p]))
	# Lab navigation is single-surface. Refuse edits that remove that ground,
	# trap the player or disconnect the reserved city targets.
	if not plan.walkable(player_cell) or not plan.validate(player_cell):
		for p: Vector3i in inverse: _put(plan.blocks,p,int(inverse[p]))
		return false
	for p: Vector3i in inverse: _record(p,int(patch[p]))
	if remember:
		undo_stack.append(inverse)
		if undo_stack.size() > 32: undo_stack.pop_front()
	return true

func undo(plan, player_cell: Vector2i) -> Dictionary:
	if undo_stack.is_empty(): return {}
	var inverse: Dictionary = undo_stack.back()
	if not apply(plan,inverse,player_cell,false): return {}
	undo_stack.pop_back()
	return inverse

func dirty_sections(patch: Dictionary) -> Dictionary:
	var dirty: Dictionary = {}
	for p: Vector3i in patch:
		dirty[mesher.section_of(p)] = true
		for d in Mesher.NORMALS:
			dirty[mesher.section_of(p+d)] = true
	return dirty

func _identity(seed_value: int, rx: int, rz: int) -> String:
	# JSON never carries the large address as a floating-point number.
	return "%d:%d:%d:%s" % [seed_value,rx,rz,GENERATOR]

func filename(seed_value: int, rx: int, rz: int) -> String:
	return "user://city_lab_%s.json" % _identity(seed_value,rx,rz).sha256_text()

func encode(seed_value: int, rx: int, rz: int) -> Dictionary:
	var rows: Array = []
	for p: Vector3i in changes:
		rows.append([p.x,p.y,p.z,int(changes[p])])
	return {"schema_version":SCHEMA,"identity":_identity(seed_value,rx,rz),"changes":rows}

func decode(root: Variant, seed_value: int, rx: int, rz: int) -> Variant:
	if not root is Dictionary or root.get("schema_version",0) != SCHEMA or root.get("identity","") != _identity(seed_value,rx,rz): return null
	var rows: Variant = root.get("changes")
	if not rows is Array or rows.size() > MAX_EDITS: return null
	var patch: Dictionary = {}
	for row in rows:
		if not row is Array or row.size() != 4: return null
		for item in row:
			if not prefab._integer(item): return null
		var p := Vector3i(int(row[0]),int(row[1]),int(row[2]))
		var value := int(row[3])
		if not prefab.inside(p) or value < -1 or value > 6 or patch.has(p): return null
		patch[p] = value
	return patch

func write_json(path: String, root: Dictionary) -> bool:
	var temp := path+".tmp"
	var f := FileAccess.open(temp,FileAccess.WRITE)
	if f == null: return false
	f.store_string(JSON.stringify(root))
	f.flush()
	var ok := f.get_error() == OK
	f.close()
	if not ok: return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(temp),ProjectSettings.globalize_path(path)) == OK

func read_json(path: String) -> Variant:
	var f := FileAccess.open(path,FileAccess.READ)
	if f == null or f.get_length() > MAX_FILE_BYTES: return null
	var result: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return result
