extends RefCounted
## World-grounded zone names for the minimap; no fabricated geography.
## Outpost's deterministic coastal sampler is the source of truth.
static func resolve(position: Vector3, biome: Node, in_dungeon: bool = false) -> String:
	if in_dungeon:
		return "DUNGEON"
	if biome == null or not biome.has_method("coast_zone_at"):
		return "OUTPOST CLEARING"
	var x: float = position.x
	var z: float = position.z
	var kind: String = str(biome.coast_zone_at(x, z))
	match kind:
		"water":
			return "OPEN WATER"
		"wet_sand":
			return "TIDAL SHORE"
		"dry_sand", "grass_sand":
			return "SANDY COAST"
		"coastal_soil":
			return "COASTAL FIELDS"
		_:
			return "OUTPOST CLEARING" if Vector2(x, z).length_squared() < 24.0 * 24.0 else "THE FIELDS"
