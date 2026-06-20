extends Object
class_name WorldFile
## Source of truth for authored-world file paths + objects.json load/save.

const OBJECTS := "res://assets/world/objects.json"
const PREFAB_DIR := "res://assets/world/prefabs"
const HEIGHTMAP := "res://assets/terrain/heightmap.png"
const BIOME := "res://assets/terrain/biome.png"
const WATERMASK := "res://assets/terrain/watermask.png"
const FOGMASK := "res://assets/terrain/fogmask.png"
const PAINTMASK := "res://assets/terrain/paintmask.png"
const LIGHTING := "res://assets/world/lighting.json"
const HM_RANGE_FILE := "res://assets/terrain/heightrange.json"

# Heightmap grayscale↔elevation mapping — read THESE; never hardcode.
const HM_MIN := -16.0
const HM_MAX := 96.0
const _OLD_HM_MIN := -8.0
const _OLD_HM_MAX := 48.0

## Remap a legacy (unmarked) heightmap in memory from the old range so elevations stay the same.
static func remap_legacy_heightmap(img: Image) -> bool:
	if img == null or heightmap_is_current():
		return false
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RF)
	for y in img.get_height():
		for x in img.get_width():
			var old_elev := _OLD_HM_MIN + img.get_pixel(x, y).r * (_OLD_HM_MAX - _OLD_HM_MIN)
			var nr := (old_elev - HM_MIN) / (HM_MAX - HM_MIN)
			img.set_pixel(x, y, Color(nr, nr, nr))
	return true

static func heightmap_is_current() -> bool:
	if not FileAccess.file_exists(HM_RANGE_FILE):
		return false
	var f := FileAccess.open(HM_RANGE_FILE, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	return d is Dictionary and float(d.get("min", 0.0)) == HM_MIN and float(d.get("max", 0.0)) == HM_MAX

static func mark_heightmap_current() -> void:
	var f := FileAccess.open(HM_RANGE_FILE, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"min": HM_MIN, "max": HM_MAX}))
		f.close()

const KINDS := ["node", "prop", "building", "cave", "start", "block", "decor", "water_src"]

static func load_entries() -> Array:
	if not FileAccess.file_exists(OBJECTS):
		return []
	var f := FileAccess.open(OBJECTS, FileAccess.READ)
	if f == null:
		return []
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Array else []

static func save_entries(entries: Array) -> void:
	var f := FileAccess.open(OBJECTS, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(entries, "  "))
		f.close()
