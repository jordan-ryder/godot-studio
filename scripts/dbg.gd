class_name Dbg
extends Object

static var _f: FileAccess = null
static var _opened := false

static func say(msg: String) -> void:
	print("[dbg] ", msg)
	if not _opened:
		_opened = true
		_f = FileAccess.open("res://_dbg.log", FileAccess.WRITE)
	if _f != null:
		_f.store_line("%8.1f  %s" % [Time.get_ticks_msec() / 1000.0, msg])
		_f.flush()
