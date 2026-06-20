extends SceneTree
## Headless logic test for MapStore (map bundles, slugs, current pointer).
## Run under an ISOLATED XDG_DATA_HOME so user:// is a throwaway:
##   XDG_DATA_HOME=$(mktemp -d) ./.godot-bin/godot --headless --script res://tests/map_store_test.gd
## Prints "MAPSTORE_TEST PASS" / "... FAIL (...)" and exits.

var _fails: Array = []

func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)

func _initialize() -> void:
	# slugify
	_check(MapStore.slugify("North Village!!") == "north-village", "slugify name")
	_check(MapStore.slugify("  a  b ") == "a-b", "slugify spaces")
	_check(MapStore.slugify("***") == "map", "slugify empty fallback")

	# create + dedup + meta display name
	var s1 := MapStore.create("Town Square")
	_check(s1 == "town-square", "create slug: " + s1)
	_check(MapStore.exists(s1), "created dir exists")
	_check(MapStore.display_name(s1) == "Town Square", "display name from meta")
	var s2 := MapStore.create("Town Square")
	_check(s2 == "town-square-2", "dedup slug: " + s2)

	# current pointer
	MapStore.set_current(s1)
	_check(MapStore.get_current() == s1, "current roundtrip")

	# list (sorted by display name): both town squares present
	var names := []
	for m in MapStore.list_maps():
		names.append(m["slug"])
	_check(names.has(s1) and names.has(s2), "list contains created maps")

	# active_or_migrate: with a current already set, returns it (idempotent)
	_check(MapStore.active_or_migrate() == s1, "active_or_migrate honors current")

	if _fails.is_empty():
		print("MAPSTORE_TEST PASS")
	else:
		print("MAPSTORE_TEST FAIL: ", _fails)
	quit()
