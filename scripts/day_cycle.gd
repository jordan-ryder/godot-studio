extends Object
class_name DayCycle
## Sun core for the editor's time-of-day slider.

static func day_amount(t: float) -> float:
	return clampf(sin((t - 0.25) * TAU), 0.0, 1.0)

static func night_amount(t: float) -> float:
	return clampf(-sin((t - 0.25) * TAU) * 4.0, 0.0, 1.0)

## Unit vector toward the sun: arcs east(+X)->west(-X), held just above the horizon so shadows never flip underground.
static func toward_sun(t: float) -> Vector3:
	var day_angle := (t - 0.25) * TAU
	var sun_y := maxf(sin(day_angle), 0.06)
	return Vector3(cos(day_angle), sun_y, 0.30).normalized()

## Aim a DirectionalLight3D away from the sun (standard convention).
static func aim_sun(light: DirectionalLight3D, t: float) -> void:
	var ts := toward_sun(t)
	light.look_at(light.global_position - ts, Vector3.UP)

## Mist-wall relief-lighting energies (set_mist_sun + editor preview).
static func mist_sun_energy(t: float) -> float:
	return lerpf(0.25, 1.1, day_amount(t))

static func mist_ambient(t: float) -> float:
	return lerpf(0.16, 0.35, day_amount(t))
