extends SceneTree
## Unified headless runner for the SceneTree logic tests (idiom review item 9).
## Spawns each test as its own process (isolation: a crash in one can't take down the
## rest), tallies pass/fail, and exits non-zero if any failed — one command for CI:
##   ./.godot-bin/godot --headless --script res://tests/run_all.gd
## or just ./run_tests.sh

const SKIP := ["run_all.gd"]

func _gather() -> Array:
	var out: Array = []
	var d := DirAccess.open("res://tests")
	if d != null:
		for f in d.get_files():
			if f.ends_with(".gd") and not (f in SKIP):
				out.append("res://tests/" + f)
	out.sort()
	return out

func _initialize() -> void:
	var exe := OS.get_executable_path()
	var proj := ProjectSettings.globalize_path("res://")
	var tests := _gather()
	var failed: Array = []
	print("Running %d test(s)\n" % tests.size())
	for t in tests:
		var out: Array = []
		var code := OS.execute(exe, ["--headless", "--path", proj, "--script", t], out, true)
		var text: String = out[0] if out.size() > 0 else ""
		if code == 0:
			print("  PASS  ", t)
		else:
			failed.append(t)
			print("  FAIL  ", t, "  (exit ", code, ")")
			for line in text.split("\n"):
				var s := line.strip_edges()
				if s.contains("FAIL") or s.contains("SCRIPT ERROR"):
					print("          ", s)
	print("\n== %d passed, %d failed ==" % [tests.size() - failed.size(), failed.size()])
	quit(0 if failed.is_empty() else 1)
