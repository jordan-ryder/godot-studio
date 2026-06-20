class_name WindDial
extends Control

signal changed(angle: float)

var angle := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(76, 76)

func set_angle(a: float) -> void:
	angle = a
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(c.x, c.y) - 8.0
	draw_circle(c, r, Color(0.09, 0.11, 0.15, 0.85))
	draw_arc(c, r, 0.0, TAU, 40, Color(0.45, 0.55, 0.7), 2.0)
	var f := ThemeDB.fallback_font
	for nesw in [["N", Vector2(0, -1)], ["E", Vector2(1, 0)], ["S", Vector2(0, 1)], ["W", Vector2(-1, 0)]]:
		var p: Vector2 = c + (nesw[1] as Vector2) * (r - 9.0) - Vector2(4, -4)
		draw_string(f, p, str(nesw[0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.6, 0.66, 0.78))
	var dir := Vector2(cos(angle), sin(angle))
	var tip := c + dir * (r - 6.0)
	var perp := Vector2(-dir.y, dir.x)
	draw_line(c - dir * (r - 18.0), tip, Color(0.6, 0.92, 1.0), 3.0)
	draw_line(tip, tip - dir * 11.0 + perp * 6.0, Color(0.6, 0.92, 1.0), 3.0)
	draw_line(tip, tip - dir * 11.0 - perp * 6.0, Color(0.6, 0.92, 1.0), 3.0)

func _gui_input(e: InputEvent) -> void:
	var dragging := false
	if e is InputEventMouseButton and e.pressed:
		dragging = true
	elif e is InputEventMouseMotion and (e.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		dragging = true
	if dragging:
		var v: Vector2 = e.position - size * 0.5
		if v.length() > 2.0:
			angle = atan2(v.y, v.x)
			queue_redraw()
			changed.emit(angle)
