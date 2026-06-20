class_name AmbientMotes
extends Node3D

var _p: CPUParticles3D

func _ready() -> void:
	_p = CPUParticles3D.new()
	_p.local_coords = false
	_p.amount = 80
	_p.lifetime = 10.0
	_p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_p.emission_box_extents = Vector3(16, 9, 16)
	_p.gravity = Vector3(0.0, -0.04, 0.0)
	_p.direction = Vector3(1.0, 0.15, 0.4)
	_p.spread = 180.0
	_p.initial_velocity_min = 0.05
	_p.initial_velocity_max = 0.28
	var qm := QuadMesh.new()
	qm.size = Vector2(0.035, 0.035)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.97, 0.86, 0.5)
	m.albedo_texture = WeatherSystem._soft()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.billboard_keep_scale = true
	qm.material = m
	_p.mesh = qm
	_p.emitting = true
	add_child(_p)

func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		_p.global_position = cam.global_position
