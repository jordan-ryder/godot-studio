class_name MapStore
extends Object

const ROOT := "user://maps"
const CURRENT := "user://current_map.txt"

const F_HM := "heightmap.png"
const F_BM := "biome.png"
const F_WM := "watermask.png"
const F_FM := "fogmask.png"
const F_PM := "paintmask.png"
const F_OBJ := "objects.json"
const F_META := "meta.json"
const F_SM := "smart_id.png"             # editor-only: which smart material owns each texel (0 = none)
const F_SMART := "smart_materials.json"

static func _ensure_root() -> void:
	if not DirAccess.dir_exists_absolute(ROOT):
		DirAccess.make_dir_recursive_absolute(ROOT)

static func dir_for(slug: String) -> String:
	return "%s/%s" % [ROOT, slug]

static func path(slug: String, fname: String) -> String:
	return "%s/%s/%s" % [ROOT, slug, fname]

static func exists(slug: String) -> bool:
	return not slug.is_empty() and DirAccess.dir_exists_absolute(dir_for(slug))

## A display name -> a filesystem-safe folder slug (lowercase, dashed).
static func slugify(name: String) -> String:
	var out := ""
	for ch in name.strip_edges().to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif ch == " " or ch == "_" or ch == "-":
			out += "-"
	while out.contains("--"):
		out = out.replace("--", "-")
	out = out.lstrip("-").rstrip("-")
	return out if not out.is_empty() else "map"

static func display_name(slug: String) -> String:
	var p := path(slug, F_META)
	if FileAccess.file_exists(p):
		var d = JSON.parse_string(FileAccess.get_file_as_string(p))
		if d is Dictionary and d.has("name"):
			return str(d["name"])
	return slug

## Every map on disk as [{slug, name}], sorted by display name.
static func list_maps() -> Array:
	_ensure_root()
	var out: Array = []
	var d := DirAccess.open(ROOT)
	if d == null:
		return out
	d.list_dir_begin()
	var n := d.get_next()
	while n != "":
		if d.current_is_dir() and not n.begins_with("."):
			out.append({"slug": n, "name": display_name(n)})
		n = d.get_next()
	d.list_dir_end()
	out.sort_custom(func(a, b): return String(a["name"]).naturalnocasecmp_to(String(b["name"])) < 0)
	return out

## Create an empty map (editor fills defaults on load). Returns the deduped slug.
static func create(name: String) -> String:
	_ensure_root()
	var base := slugify(name)
	var slug := base
	var i := 2
	while exists(slug):
		slug = "%s-%d" % [base, i]
		i += 1
	DirAccess.make_dir_recursive_absolute(dir_for(slug))
	write_meta(slug, name.strip_edges() if not name.strip_edges().is_empty() else slug)
	return slug

static func write_meta(slug: String, name: String) -> void:
	var f := FileAccess.open(path(slug, F_META), FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"name": name}))
		f.close()

static func get_current() -> String:
	if FileAccess.file_exists(CURRENT):
		var s := FileAccess.get_file_as_string(CURRENT).strip_edges()
		if exists(s):
			return s
	return ""

static func set_current(slug: String) -> void:
	var f := FileAccess.open(CURRENT, FileAccess.WRITE)
	if f != null:
		f.store_string(slug)
		f.close()

## Active slug, folding the legacy single world into a "Default" map on first run. Idempotent.
static func active_or_migrate() -> String:
	_ensure_root()
	var cur := get_current()
	if cur != "":
		return cur
	var existing := list_maps()
	if not existing.is_empty():
		var slug := String(existing[0]["slug"])
		set_current(slug)
		return slug
	var first := create("Default")
	for pair in [[WorldFile.HEIGHTMAP, F_HM], [WorldFile.BIOME, F_BM],
			[WorldFile.WATERMASK, F_WM], [WorldFile.FOGMASK, F_FM],
			[WorldFile.PAINTMASK, F_PM]]:
		_copy_if(pair[0], path(first, pair[1]))
	_copy_if(WorldFile.OBJECTS, path(first, F_OBJ))
	set_current(first)
	return first

static func _copy_if(src: String, dst: String) -> void:
	if not FileAccess.file_exists(src):
		return
	var bytes := FileAccess.get_file_as_bytes(src)
	var f := FileAccess.open(dst, FileAccess.WRITE)
	if f != null:
		f.store_buffer(bytes)
		f.close()
