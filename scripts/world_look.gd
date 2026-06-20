extends Object
class_name WorldLook

const DEFAULTS := {
	"sun_day_energy": 1.5,
	"sun_night_energy": 0.34,
	"sun_warm": [1.0, 0.93, 0.78],
	"moon": [0.55, 0.66, 1.0],
	"ambient_day_energy": 0.6,
	"ambient_night_energy": 0.42,
	"ambient_day": [0.62, 0.68, 0.78],
	"ambient_night": [0.20, 0.25, 0.38],
	"sky_top_day": [0.14, 0.34, 0.74],
	"sky_top_night": [0.010, 0.013, 0.030],
	"sky_hor_day": [0.45, 0.64, 0.87],
	"sky_hor_night": [0.028, 0.034, 0.065],
	"mist_density": 1.0,
	"mist_ceiling": 0.0,
	"mist_face_sharp": 0.0,
	"mist_color_day": [0.55, 0.56, 0.59],
	"mist_color_night": [0.40, 0.41, 0.46],
	"ground_grass_low": [0.26, 0.45, 0.20],
	"ground_grass_high": [0.50, 0.64, 0.31],
	"ground_dirt": [0.42, 0.34, 0.21],
	"ground_sand": [0.78, 0.72, 0.52],
	"ground_rock": [0.46, 0.44, 0.41],
	"mat_tile": 0.5,
	"tonemap": "agx",
	"exposure": 1.0,
	"glow": false,
	"ssil": true,
	"sdfgi": false,
	"wind_angle": 0.55,
	"wind_speed": 1.4,
	"wind_strength": 0.18,
	"foliage_variation": 0.18,
	"foliage_detail": 0.6,
	"foliage_normal_up": 0.4,
	"foliage_edge_shade": 0.25,
	"foliage_backlight": 0.35,
	"weather": "clear",
	"brightness": 1.0,
	"contrast": 1.0,
	"saturation": 1.0,
	"godray": 1.0,
}

const TONEMAP := {
	"agx": Environment.TONE_MAPPER_AGX, "filmic": Environment.TONE_MAPPER_FILMIC,
	"aces": Environment.TONE_MAPPER_ACES, "reinhard": Environment.TONE_MAPPER_REINHARDT,
}

## Apply the authored post/pipeline + foliage look to an Environment.
static func apply_pipeline(env: Environment) -> void:
	env.tonemap_mode = TONEMAP.get(text("tonemap"), Environment.TONE_MAPPER_AGX)
	env.tonemap_exposure = num("exposure")
	env.glow_enabled = flag("glow")
	env.ssil_enabled = flag("ssil")
	env.sdfgi_enabled = flag("sdfgi")
	env.adjustment_enabled = true
	env.adjustment_brightness = num("brightness")
	env.adjustment_contrast = num("contrast")
	env.adjustment_saturation = num("saturation")
	RenderingServer.global_shader_parameter_set("foliage_variation", num("foliage_variation"))
	RenderingServer.global_shader_parameter_set("foliage_detail", num("foliage_detail"))
	RenderingServer.global_shader_parameter_set("foliage_normal_up", num("foliage_normal_up"))
	RenderingServer.global_shader_parameter_set("foliage_edge_shade", num("foliage_edge_shade"))
	RenderingServer.global_shader_parameter_set("foliage_backlight", num("foliage_backlight"))

static func flag(key: String) -> bool:
	return bool(settings()[key])

static func text(key: String) -> String:
	return str(settings()[key])

static var _cached: Dictionary = {}

# Mirrors the `wind_strength` shader global for cheap per-frame reads — global_shader_parameter_get
static var wind_gated := 0.18

## Set gated wind on both the shader global and wind_gated. Use instead of global_shader_parameter_set("wind_strength", ...).
static func gate_wind(strength: float) -> void:
	wind_gated = strength
	RenderingServer.global_shader_parameter_set("wind_strength", strength)

## Merged settings (defaults ⊕ lighting.json). Cached; reload() after a save to refresh.
static func settings() -> Dictionary:
	if _cached.is_empty():
		_cached = DEFAULTS.duplicate(true)
		if FileAccess.file_exists(WorldFile.LIGHTING):
			var f := FileAccess.open(WorldFile.LIGHTING, FileAccess.READ)
			if f != null:
				var data = JSON.parse_string(f.get_as_text())
				if data is Dictionary:
					for k in data:
						if _cached.has(k):
							_cached[k] = data[k]
	return _cached

static func reload() -> void:
	_cached = {}

static func save(d: Dictionary) -> void:
	var out := {}
	for k in d:
		if DEFAULTS.has(k):
			out[k] = d[k]
	var f := FileAccess.open(WorldFile.LIGHTING, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(out, "  "))
		f.close()
	_cached = {}

static func col(key: String) -> Color:
	var a = settings()[key]
	if a is Array and a.size() >= 3:
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return Color.WHITE

static func num(key: String) -> float:
	return float(settings()[key])

const SUN_DAY_REF := 1.5

## Day ambient scales with the sun (skylight = scattered sunlight); night ambient is independent.
static func ambient_energy(day: float) -> float:
	var sun_scale := num("sun_day_energy") / SUN_DAY_REF
	return lerpf(num("ambient_night_energy"), num("ambient_day_energy") * sun_scale, day)

## Mist day/night param dicts with look overrides applied (editor preview reads these).
static func mist_day(base: Dictionary) -> Dictionary:
	return _mist_merge(base)

static func mist_night(base: Dictionary) -> Dictionary:
	return _mist_merge(base)

static func _mist_merge(base: Dictionary) -> Dictionary:
	var out := base.duplicate()
	if num("mist_ceiling") > 0.0:
		out["base_ceiling"] = num("mist_ceiling")
	if num("mist_face_sharp") > 0.0:
		out["face_sharp"] = num("mist_face_sharp")
	return out

## Push ground tint/tiling overrides onto a ground ShaderMaterial.
static func apply_ground(mat: ShaderMaterial) -> void:
	mat.set_shader_parameter("grass_low", col("ground_grass_low"))
	mat.set_shader_parameter("grass_high", col("ground_grass_high"))
	mat.set_shader_parameter("dirt", col("ground_dirt"))
	mat.set_shader_parameter("sand", col("ground_sand"))
	mat.set_shader_parameter("rock", col("ground_rock"))
	mat.set_shader_parameter("mat_tile", num("mat_tile"))
