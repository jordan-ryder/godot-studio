class_name WeatherSystem
extends Node3D

var _p: CPUParticles3D
var _kind := "clear"
var _fall := 30.0
var _wind_k := 8.0
var center = null
static var _soft_tex: Texture2D = null
static var _rain_tex: Texture2D = null

func _ready() -> void:
	_p = CPUParticles3D.new()
	_p.local_coords = false
	_p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_p.direction = Vector3(0, -1, 0)
	_p.emitting = false
	add_child(_p)
	set_weather(_kind)

# kind -> amount, lifetime, fall accel, sideways wind factor, half-width, mesh
func set_weather(kind: String) -> void:
	_kind = kind
	match kind:
		"rain-light": _precip(900, 1.3, 28.0, 5.0, 44.0, _streak(0.4))
		"rain":       _precip(2200, 1.2, 34.0, 7.0, 46.0, _streak(0.5))
		"rain-heavy": _precip(4200, 1.1, 40.0, 9.0, 46.0, _streak(0.6))
		"snow":       _precip(3200, 9.0, 3.0, 5.0, 40.0, _flake(0.14, Color(1, 1, 1, 0.95)))
		"blizzard":   _precip(13000, 4.0, 8.0, 16.0, 38.0, _flake(0.26, Color(1, 1, 1, 0.98)))
		"mist":       _precip(110, 18.0, 0.05, 2.0, 30.0, _flake(3.4, Color(0.82, 0.86, 0.92, 0.07)))
		_:
			_p.emitting = false
			return
	_p.emitting = true
	_apply_wind()

func _precip(amount: int, life: float, fall: float, wind_k: float, half: float, mesh: Mesh) -> void:
	_p.amount = maxi(1, amount)
	_p.lifetime = life
	_fall = fall
	_wind_k = wind_k
	_p.emission_box_extents = Vector3(half, 14.0, half)
	_p.initial_velocity_min = fall * 0.2 + 0.3
	_p.initial_velocity_max = fall * 0.4 + 0.8
	_p.spread = (8.0 if fall > 12.0 else 50.0)
	_p.mesh = mesh

## Push particles sideways with the authored wind so rain slants and snow blizzards.
func _apply_wind() -> void:
	var a := WorldLook.num("wind_angle")
	var st := WorldLook.num("wind_strength")
	var d := Vector2(cos(a), sin(a))
	# Cap sideways speed relative to fall so precip never flies horizontally out of view.
	var side := minf(_wind_k * (0.3 + st * 2.2), _fall * 2.2 + 6.0)
	_p.gravity = Vector3(d.x * side, -_fall, d.y * side)

func _process(_dt: float) -> void:
	if not _p.emitting:
		return
	var high := 0.0 if _kind == "mist" else 4.0
	if center != null:
		_p.global_position = (center as Vector3) + Vector3(0, high, 0)
	else:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			_p.global_position = cam.global_position + Vector3(0, high, 0)
	_apply_wind()

func _streak(length: float) -> Mesh:
	var qm := QuadMesh.new()
	qm.size = Vector2(maxf(0.05, length * 0.05), length)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.74, 0.82, 0.95, 0.5)
	m.albedo_texture = _rain_sprite()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.billboard_keep_scale = true
	qm.material = m
	return qm

func _flake(size: float, col: Color) -> Mesh:
	var qm := QuadMesh.new()
	qm.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.albedo_texture = _soft()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	qm.material = m
	return qm

## Soft vertical rain streak: bright centre, faded ends + edges.
static func _rain_sprite() -> Texture2D:
	if _rain_tex != null:
		return _rain_tex
	var W := 8; var H := 48
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	for y in H:
		var v := float(y) / float(H - 1)
		var vert := smoothstep(0.0, 0.2, v) * smoothstep(1.0, 0.75, v)
		for x in W:
			var u := absf(float(x) - float(W - 1) * 0.5) / (float(W - 1) * 0.5)
			var horiz := clampf(1.0 - u, 0.0, 1.0); horiz = horiz * horiz
			img.set_pixel(x, y, Color(1, 1, 1, vert * horiz))
	img.generate_mipmaps()
	_rain_tex = ImageTexture.create_from_image(img)
	return _rain_tex

## Soft round alpha sprite (mip-mapped) for flakes/mist puffs.
static func _soft() -> Texture2D:
	if _soft_tex != null:
		return _soft_tex
	var N := 64
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var dd := Vector2(float(x) - float(N - 1) * 0.5, float(y) - float(N - 1) * 0.5).length() / (float(N) * 0.5)
			var a := smoothstep(1.0, 0.0, dd)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	img.generate_mipmaps()
	_soft_tex = ImageTexture.create_from_image(img)
	return _soft_tex
