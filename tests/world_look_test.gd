extends SceneTree
## Headless test for WorldLook's post/pipeline additions (look-dev backend).
## Read-only: never calls save(), so it can't touch assets/world/lighting.json.
## Run: ./.godot-bin/godot --headless --script res://tests/world_look_test.gd

var _fails: Array = []

func _check(ok: bool, msg: String) -> void:
	if not ok:
		_fails.append(msg)

func _initialize() -> void:
	# New keys exist with sane defaults.
	_check(WorldLook.TONEMAP.has(WorldLook.text("tonemap")), "tonemap default is a known mode: " + WorldLook.text("tonemap"))
	_check(WorldLook.flag("ssil"), "ssil defaults on")
	_check(not WorldLook.flag("sdfgi"), "sdfgi defaults off")   # off by default (box-shadow fix); was a stale assert
	_check(absf(WorldLook.num("wind_speed") - 1.4) < 0.001, "wind_speed default")
	_check(absf(WorldLook.num("foliage_variation") - 0.18) < 0.001, "foliage_variation default")

	# apply_pipeline pushes the authored look onto an Environment.
	var e := Environment.new()
	WorldLook.apply_pipeline(e)
	_check(e.tonemap_mode == WorldLook.TONEMAP[WorldLook.text("tonemap")], "apply: tonemap enum")
	_check(e.ssil_enabled == WorldLook.flag("ssil"), "apply: ssil")
	_check(e.sdfgi_enabled == WorldLook.flag("sdfgi"), "apply: sdfgi")
	_check(absf(e.tonemap_exposure - WorldLook.num("exposure")) < 0.001, "apply: exposure")
	_check(e.glow_enabled == WorldLook.flag("glow"), "apply: glow")

	# Wind/variation globals are registered for the push to land on.
	var globals := RenderingServer.global_shader_parameter_get_list()
	_check(globals.has(&"wind_angle") and globals.has(&"foliage_variation"), "wind/variation globals registered")

	if _fails.is_empty():
		print("WORLD_LOOK_TEST PASS")
		quit(0)
		return
	for f in _fails:
		print("  FAIL: ", f)
	print("WORLD_LOOK_TEST FAIL (", _fails.size(), ")")
	quit(1)
