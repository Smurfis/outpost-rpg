extends RefCounted
## Footprints shared by starter props, streamed resources and landmarks.
## Dead weak references are removed when chunks unload.
var entries: Array[Dictionary] = []

func reserve(at: Vector3, radius: float, owner: Node = null) -> void:
	entries.append({"at": Vector2(at.x, at.z), "radius": radius,
		"owner": weakref(owner) if owner != null else null})

func available(at: Vector3, radius: float) -> bool:
	for i in range(entries.size() - 1, -1, -1):
		var entry: Dictionary = entries[i]
		if entry.owner != null and entry.owner.get_ref() == null:
			entries.remove_at(i)
			continue
		if Vector2(at.x, at.z).distance_to(entry.at) < radius + float(entry.radius) + 0.3:
			return false
	return true

static func radius_for(kind: String, count: int = 1) -> float:
	var radius: float = 1.65 if kind == "wood" else 1.15 if kind in ["stone", "iron", "coal", "clay"] else 0.85
	return radius + (0.8 if count > 1 else 0.0)
