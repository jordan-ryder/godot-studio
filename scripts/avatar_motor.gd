extends RefCounted
class_name AvatarMotor

const WALK := 2.8
const SPRINT := 4.6
const GRAVITY := 18.0
const JUMP := 8.4
const JUMP_BUFFER_TIME := 0.18
const COYOTE_TIME := 0.12       # ground-grace after stepping off an edge

var jump_buffer := 0.0
var coyote := 0.0
var pending_launch := 0.0
var pending_impulse := Vector3.ZERO

## Standard avatar body: feet-origin capsule, slides vs terrain/buildings/set-pieces, 60° walkable.
static func make_body(full_height: float = 0.62) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = 0
	body.collision_mask = Config.PHYS_TERRAIN | Config.PHYS_BUILDING | Config.PHYS_SETPIECE
	body.floor_max_angle = deg_to_rad(60.0)
	body.floor_snap_length = 0.6
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = clampf(full_height * 0.28, 0.08, full_height * 0.49)
	cap.height = full_height
	cs.shape = cap
	cs.position = Vector3(0, cap.height * 0.5, 0)
	body.add_child(cs)
	return body

func press_jump() -> void:
	jump_buffer = JUMP_BUFFER_TIME

func launch(up_speed: float) -> void:
	pending_launch = maxf(pending_launch, up_speed)

func add_impulse(v: Vector3) -> void:
	pending_impulse += v

## One physics tick. wish_dir = horizontal intent (zero = stop); can_jump vetoes (stamina).
func tick(body: CharacterBody3D, delta: float, wish_dir: Vector3, sprinting: bool,
		can_jump: bool = true) -> Dictionary:
	var vel := body.velocity
	var speed := SPRINT if sprinting else WALK
	if wish_dir.length() > 0.01:
		var d := wish_dir.normalized()
		vel.x = d.x * speed
		vel.z = d.z * speed
	else:
		vel.x = 0.0
		vel.z = 0.0
	var on_floor := body.is_on_floor()
	if on_floor:
		coyote = COYOTE_TIME
		vel.y = -2.0
	else:
		coyote = maxf(0.0, coyote - delta)
		vel.y -= GRAVITY * delta
	jump_buffer = maxf(0.0, jump_buffer - delta)
	var jumped := false
	if jump_buffer > 0.0 and (on_floor or coyote > 0.0) and can_jump:
		vel.y = JUMP
		jump_buffer = 0.0
		coyote = 0.0
		jumped = true
	if pending_launch > 0.0:
		vel.y = maxf(vel.y, pending_launch)
		pending_launch = 0.0
		coyote = 0.0
	if pending_impulse != Vector3.ZERO:
		vel += pending_impulse
		pending_impulse = Vector3.ZERO
	body.velocity = vel
	body.move_and_slide()
	return {"jumped": jumped, "on_floor": body.is_on_floor()}
