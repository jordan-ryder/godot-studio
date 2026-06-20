extends SceneTree
## Headless logic test for SmartMaterial: rule evaluation (first-match-wins, the > and
## < operators, steepness vs height), JSON round-trip, and the material-index <-> biome
## pixel encoding the bake relies on. Run:
##   ./.godot-bin/godot --headless --script res://tests/smart_material_test.gd

const SM = preload("res://scripts/smart_material.gd")

var _fails: Array = []
func _ck(ok: bool, msg: String) -> void:
	if not ok: _fails.append(msg)

func _initialize() -> void:
	# evaluate: the default preset (grass base; rock on steep; snow up high)
	var d := SM.make_default("m")
	_ck(SM.evaluate(d, 10.0, 0.10) == 0, "flat low -> base grass")
	_ck(SM.evaluate(d, 10.0, 0.50) == 4, "steep low -> rock")
	_ck(SM.evaluate(d, 60.0, 0.10) == 3, "flat high -> snow")
	# steep AND high: the first matching rule (steepness, listed first) wins
	_ck(SM.evaluate(d, 60.0, 0.50) == 4, "steep+high -> rock (first match wins)")

	# order matters: reverse the rules and height now wins the same tie
	var d2 := {"base": 0, "rules": [
		{"type": "height", "op": ">", "value": 50.0, "mat": 3},
		{"type": "steepness", "op": ">", "value": 0.4, "mat": 4}]}
	_ck(SM.evaluate(d2, 60.0, 0.50) == 3, "reordered -> height wins the tie")

	# the "<" operator and base fallback
	var d3 := {"base": 1, "rules": [{"type": "height", "op": "<", "value": 20.0, "mat": 2}]}
	_ck(SM.evaluate(d3, 10.0, 0.0) == 2, "height < 20 -> mat 2")
	_ck(SM.evaluate(d3, 30.0, 0.0) == 1, "height >= 20 -> base")
	_ck(SM.evaluate({"base": 7, "rules": []}, 99.0, 0.9) == 7, "no rules -> base")

	# above / below elevation, including negative thresholds (below water)
	var d4 := {"base": 0, "rules": [{"type": "height", "op": "<", "value": 0.0, "mat": 5}]}
	_ck(SM.evaluate(d4, -5.0, 0.0) == 5, "below elevation 0 (underwater) -> mat 5")
	_ck(SM.evaluate(d4, 5.0, 0.0) == 0, "above elevation 0 -> base")
	var d5 := {"base": 0, "rules": [{"type": "height", "op": ">", "value": 70.0, "mat": 3}]}
	_ck(SM.evaluate(d5, 80.0, 0.0) == 3, "above elevation 70 -> mat 3")
	_ck(SM.evaluate(d5, 60.0, 0.0) == 0, "below elevation 70 -> base")

	# blend feathers a rule's threshold: at the exact boundary, per-texel jitter flips it
	var db := {"base": 0, "blend": 0.5, "rules": [{"type": "steepness", "op": ">", "value": 0.4, "mat": 4}]}
	_ck(SM.evaluate(db, 5.0, 0.40, -0.5) == 4, "blend -jitter pulls rock below the threshold")
	_ck(SM.evaluate(db, 5.0, 0.40, 0.5) == 0, "blend +jitter holds grass above the threshold")
	_ck(SM.evaluate(db, 5.0, 0.40, 0.0) == 0, "blend with no jitter = hard threshold")
	# blend 0 (or absent) stays a hard edge regardless of jitter
	_ck(SM.evaluate({"base": 0, "blend": 0.0, "rules": [{"type": "steepness", "op": ">", "value": 0.4, "mat": 4}]}, 5.0, 0.40, -0.5) == 0, "blend 0 ignores jitter")

	# JSON round-trip (user:// is an isolated throwaway under the test runner)
	var path := "user://smart_mat_test.json"
	var presets := [SM.make_default("alpha"), d2]
	SM.save_all(path, presets)
	var back: Array = SM.load_all(path)
	_ck(back.size() == 2, "round-trip count")
	_ck(str(back[0].get("name")) == "alpha", "round-trip name")
	_ck(int(back[1]["rules"][0]["mat"]) == 3, "round-trip nested rule")
	_ck(SM.load_all("user://does_not_exist.json") == [], "missing file -> []")

	# bake encoding: material index -> biome pixel -> readback must be exact
	var img := Image.create(8, 1, false, Image.FORMAT_RGB8)
	var enc_ok := true
	for i in [0, 1, 3, 4, 7, 11, 12]:
		var c := float(i) / 255.0
		img.set_pixel(0, 0, Color(c, c, c))
		if int(round(img.get_pixel(0, 0).r * 255.0)) != i: enc_ok = false
	_ck(enc_ok, "index<->pixel encoding exact")

	# a tiny synthetic bake: evaluate is the per-texel decision _paint_smart bakes;
	# a slope ramp should flip grass -> rock as it passes steepness 0.4
	var got := []
	for steep in [0.0, 0.3, 0.45, 0.8]:
		got.append(SM.evaluate(SM.make_default("ramp"), 5.0, steep))
	_ck(got == [0, 0, 4, 4], "slope ramp bakes grass->rock at 0.4: %s" % str(got))

	print("SMART_MATERIAL_TEST ", "PASS" if _fails.is_empty() else "FAIL " + str(_fails))
	quit(0 if _fails.is_empty() else 1)
