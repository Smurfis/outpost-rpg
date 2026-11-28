extends RefCounted
## Adapted from the Roblox WaterWaveSampler's exponential swell and recursive
## warped octaves. Smaller amplitudes and vertical-only displacement suit
## Outpost's metre-scale voxel shorelines. One explicit render-frame clock.
const SEA_Y := -2.82
const HALF_EXTENT := 48.0
const OCTAVES := 6
const STEEPNESS := 1.2
const BASELINE := 0.4197820789351331
static var center := Vector2.ZERO
static var frame_time := 0.0
static var origin_ms := -1
static var coefficients := PackedVector4Array()
static var dynamics := PackedVector2Array()

static func initialize() -> void:
	if not coefficients.is_empty(): return
	var rng := RandomNumberGenerator.new()
	rng.seed=1337
	var amp := 0.24
	var freq := 0.46
	var speed := 1.35
	for i in range(OCTAVES):
		var angle := rng.randf_range(0.0,TAU)
		coefficients.append(Vector4(cos(angle),sin(angle),freq,rng.randf_range(0.0,TAU)))
		dynamics.append(Vector2(amp,speed))
		amp*=0.72
		freq*=1.32
		speed*=1.07

static func update(point: Vector3) -> void:
	initialize()
	if origin_ms<0: origin_ms=Time.get_ticks_msec()
	frame_time=float(Time.get_ticks_msec()-origin_ms)*0.001
	center=Vector2(floorf(point.x/2.0)*2.0,floorf(point.z/2.0)*2.0)

static func envelope(p: Vector2) -> float:
	var d := p-center
	return 1.0-smoothstep(HALF_EXTENT-8.0,HALF_EXTENT,maxf(absf(d.x),absf(d.y)))

static func height_at(p: Vector2,time: float = -1.0) -> float:
	initialize()
	var t := frame_time if time<0.0 else time
	var warp := Vector2.ZERO
	var height := 0.0
	for i in range(OCTAVES):
		var c := coefficients[i]
		var d := dynamics[i]
		var direction := Vector2(c.x,c.y)
		var phase := (p+warp).dot(direction)*c.z+t*d.y+c.w
		var swell := exp(STEEPNESS*(sin(phase)-1.0))
		height+=(swell-BASELINE)*d.x
		warp+=direction*(swell*STEEPNESS*cos(phase)*d.x)
	return height*envelope(p)

static func surface_y(at: Vector3) -> float:
	return SEA_Y+height_at(Vector2(at.x,at.z))

static func hull_pose(at: Vector3,heading: float) -> Vector3:
	# Six samples in local hull space; average height, bow/stern pitch,
	# port/starboard roll. Heading remains under player control.
	var basis := Basis(Vector3.UP,heading)
	var front := 0.0
	var rear := 0.0
	var left := 0.0
	var right := 0.0
	var sum := 0.0
	for z in [-1.0,0.0,1.0]:
		for x in [-0.58,0.58]:
			var p := at+basis*Vector3(float(x),0,float(z))
			var h := height_at(Vector2(p.x,p.z))
			sum+=h
			if z<0.0: front+=h
			if z>0.0: rear+=h
			if x<0.0: left+=h
			else: right+=h
	return Vector3(sum/6.0,clampf(atan2((front-rear)/2.0,2.0),-0.20,0.20),clampf(atan2((right-left)/3.0,1.16),-0.20,0.20))

static func configure(material: ShaderMaterial,mode: int,home_half: float) -> void:
	initialize()
	material.set_shader_parameter("wave_coefficients",coefficients)
	material.set_shader_parameter("wave_dynamics",dynamics)
	material.set_shader_parameter("wave_surface_mode",mode)
	material.set_shader_parameter("wave_home_half",home_half)
	sync(material)

static func sync(material: ShaderMaterial) -> void:
	material.set_shader_parameter("ocean_time",frame_time)
	material.set_shader_parameter("wave_center",center)
