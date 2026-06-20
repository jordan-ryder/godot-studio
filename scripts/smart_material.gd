class_name SmartMaterial
extends RefCounted

const PROP_STEEPNESS := "steepness"
const PROP_HEIGHT := "height"
const PROP_TYPES := [PROP_STEEPNESS, PROP_HEIGHT]

const BLEND_STEEP := 0.4
const BLEND_HEIGHT := 40.0

## Material index for a point. height = world metres, steepness 0..1, jitter (-0.5..0.5) feathers blended thresholds.
static func evaluate(preset: Dictionary, height: float, steepness: float, jitter := 0.0) -> int:
	var blend := float(preset.get("blend", 0.0))
	for r in preset.get("rules", []):
		var is_s := str(r.get("type", PROP_STEEPNESS)) == PROP_STEEPNESS
		var x := steepness if is_s else height
		var v := float(r.get("value", 0.0))
		if blend > 0.0:
			v += jitter * blend * (BLEND_STEEP if is_s else BLEND_HEIGHT)
		var hit := (x > v) if str(r.get("op", ">")) == ">" else (x < v)
		if hit:
			return int(r.get("mat", 0))
	return int(preset.get("base", 0))

## Starter preset (grass, rock on slopes, snow up high). Assumes default GROUND_MATERIALS order (3=snow, 4=rock).
static func make_default(nm: String) -> Dictionary:
	return {"name": nm, "base": 0, "blend": 0.25, "color": [0.90, 0.45, 0.20], "rules": [
		{"type": PROP_STEEPNESS, "op": ">", "value": 0.4, "mat": 4},
		{"type": PROP_HEIGHT, "op": ">", "value": 50.0, "mat": 3}]}

static func load_all(path: String) -> Array:
	if not FileAccess.file_exists(path):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Array else []

static func save_all(path: String, presets: Array) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(presets, "  "))
		f.close()
