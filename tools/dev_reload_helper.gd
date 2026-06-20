extends Node
## F5 hot-reload worker. Reloading godot_studio.gd from inside itself kills the executing
## call (its method table is swapped mid-flight), so the editor hands the list here — this
## node's own script isn't on it — and it re-parses + rebuilds from a clean stack.
## Lives directly under root so it survives reload_current_scene().

var paths: Array = []

func do_reload() -> void:
	for p in paths:
		var s: Script = load(str(p))
		if s == null:
			continue
		# reload() recompiles the IN-MEMORY source — pull fresh text from disk first or edits never land.
		var src := FileAccess.get_file_as_string(str(p))
		if src.is_empty() or src == s.source_code:
			continue   # unchanged or unreadable: skip the hot-swap
		s.source_code = src
		var err := s.reload(true)
		if err != OK:
			print("DEVRELOAD FAILED on %s (err %d) — old code keeps running" % [str(p), err])
			queue_free()
			return
	print("DEVRELOAD rebuilding scene")
	get_tree().reload_current_scene()
	queue_free()
