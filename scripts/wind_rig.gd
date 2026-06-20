class_name WindRig
extends Node

const BEND := 0.5
const FLUTTER := 0.22  # fast jitter the OUTER branches add on top of the slow lean

var _skel: Skeleton3D
var _rest_rot: Array = []
var _axis: Array = []
var _weight: PackedFloat32Array = PackedFloat32Array()
var _phase: PackedFloat32Array = PackedFloat32Array()
var _t := 0.0
var _wind_angle := 1e9
static var view_pos := Vector3.ZERO
static var view_set := false           # don't distance-gate until the host has set view_pos
static var max_dist := 90.0
static var force_idle := false
var _origin := Vector3.ZERO
var _origin_set := false
var _idle := false

func setup(skel: Skeleton3D) -> void:
	_skel = skel
	var n := skel.get_bone_count()
	var ys := PackedFloat32Array()
	var rad := PackedFloat32Array()
	var lo := INF
	var hi := -INF
	var base_xz := Vector2.ZERO
	for i in n:
		_rest_rot.append(skel.get_bone_pose_rotation(i))
		var o: Vector3 = skel.get_bone_global_pose(i).origin
		if i == 0:
			base_xz = Vector2(o.x, o.z)
		ys.append(o.y)
		rad.append(Vector2(o.x, o.z).distance_to(base_xz))
		lo = minf(lo, o.y); hi = maxf(hi, o.y)
	var span := maxf(0.001, hi - lo)
	var rmax := 0.001
	for r in rad:
		rmax = maxf(rmax, r)
	for i in n:
		var h := clampf((ys[i] - lo) / span, 0.0, 1.0)
		var reach := rad[i] / rmax
		var w := maxf(smoothstep(0.18, 1.0, reach), 0.5 * smoothstep(0.35, 1.0, h))
		_weight.append(pow(w, 1.35))
		_phase.append(float(i) * 0.7)
	_rebuild_axes()

## Bend axis (horizontal, perpendicular to wind) in each bone's local space, so a local rotation bends it downwind.
func _rebuild_axes() -> void:
	var wind := Vector3(cos(_wind_angle), 0.0, sin(_wind_angle))
	var bend := Vector3.UP.cross(wind)
	if bend.length() < 0.001:
		bend = Vector3(1, 0, 0)
	bend = bend.normalized()
	var sb := _skel.global_transform.basis
	_axis.clear()
	for i in _skel.get_bone_count():
		var bone_world: Basis = sb * _skel.get_bone_global_pose(i).basis
		var al: Vector3 = bone_world.inverse() * bend
		if not al.is_finite() or al.length() < 1e-4:
			al = Vector3(1, 0, 0)
		_axis.append(al.normalized())

func _process(dt: float) -> void:
	if _skel == null:
		return
	if not _origin_set:
		_origin = _skel.global_transform.origin
		_origin_set = true
	var strength: float = WorldLook.wind_gated   # weather-gated; cheap (no per-frame shader-global read)
	var far := view_set and _origin.distance_squared_to(view_pos) > max_dist * max_dist
	if force_idle or strength < 0.005 or far:
		if not _idle:
			for j in _skel.get_bone_count():
				_skel.set_bone_pose_rotation(j, _rest_rot[j])
			_idle = true
		return
	_idle = false
	var a := WorldLook.num("wind_angle")
	if absf(a - _wind_angle) > 0.01:
		_wind_angle = a
		_rebuild_axes()
	var spd := WorldLook.num("wind_speed")
	_t += dt * maxf(0.1, spd)
	for i in _skel.get_bone_count():
		var ax: Vector3 = _axis[i]
		if not ax.is_normalized():
			continue
		var sway := 0.5 + 0.5 * sin(_t + _phase[i])
		var theta := sway * strength * _weight[i] * BEND
		theta += strength * _weight[i] * _weight[i] * FLUTTER * sin(_t * 3.3 + _phase[i] * 2.7)
		_skel.set_bone_pose_rotation(i, _rest_rot[i] * Quaternion(ax, theta))
