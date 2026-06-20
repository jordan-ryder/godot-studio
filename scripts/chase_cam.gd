class_name ChaseCamControl
extends RefCounted
## Third-person control feel: mouse sensitivity, pitch limits, wheel zoom, WASD→world

const SENS := 0.005
const PITCH_MIN := -1.396
const PITCH_MAX := 1.257
const DIST_MIN := 1.4
const DIST_MAX := 8.0
const DIST_STEP := 0.3
const DIST_DEFAULT := 5.0

static func look_yaw(yaw: float, rel_x: float) -> float:
	return yaw - rel_x * SENS

static func look_pitch(pitch: float, rel_y: float) -> float:
	return clampf(pitch + rel_y * SENS, PITCH_MIN, PITCH_MAX)

static func zoom(dist: float, wheel_dir: float) -> float:
	return clampf(dist + wheel_dir * DIST_STEP, DIST_MIN, DIST_MAX)

## Polled WASD/arrows as a raw input vector (y = forward axis, x = strafe).
static func wasd() -> Vector2:
	var input := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input.y += 1.0
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input.x += 1.0
	return input

static func forward(yaw: float) -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw))

## Ground-plane move direction relative to camera yaw (normalized; ZERO when no input).
static func move_dir(yaw: float, input: Vector2) -> Vector3:
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var fwd := forward(yaw)
	var right := Vector3(-fwd.z, 0.0, fwd.x)
	var dir := fwd * (-input.y) + right * input.x
	dir.y = 0.0
	return dir.normalized() if dir.length() > 0.01 else Vector3.ZERO

## Camera offset from the followed body for a given yaw/pitch/dist.
static func offset(yaw: float, pitch: float, dist: float) -> Vector3:
	return Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
