extends RefCounted
## Stable linkage between the surface city and its dungeon site. Full identity
## is a string; the preview's RNG seed is only a derived 32-bit value.
const META := "city_lab_site_return"
const VERSION := "keep-dungeon-v1"

func identity(world_seed: int, rx: int, rz: int) -> String:
	return "%s:%d:%d:%d" % [VERSION,world_seed,rx,rz]

func dungeon_seed(world_seed: int, rx: int, rz: int) -> int:
	var digest := identity(world_seed,rx,rz).sha256_buffer()
	return int(digest[0]) | (int(digest[1])<<8) | (int(digest[2])<<16) | (int(digest[3])<<24)

func context(world_seed: int, rx: int, rz: int) -> Dictionary:
	return {"seed":world_seed,"rx":rx,"rz":rz,"site_id":identity(world_seed,rx,rz),"dungeon_seed":dungeon_seed(world_seed,rx,rz)}
