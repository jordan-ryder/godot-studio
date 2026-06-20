extends Object
class_name HeightField
## Height-sampling core. Interpolates over the EXACT triangles

static func tri_interp(h00: float, h10: float, h01: float, h11: float,
		fx: float, fz: float) -> float:
	if fx + fz <= 1.0:
		return h00 + fx * (h10 - h00) + fz * (h01 - h00)
	return h11 + (1.0 - fz) * (h10 - h11) + (1.0 - fx) * (h01 - h11)

## Sample a flat vertex grid (w × d row-major) at world (x, z), clamped.
static func sample_grid(grid: PackedFloat32Array, w: int, d: int, x: float, z: float) -> float:
	var fx := clampf(x, 0.0, float(w - 1))
	var fz := clampf(z, 0.0, float(d - 1))
	var x0 := mini(int(fx), w - 2)
	var z0 := mini(int(fz), d - 2)
	var x1 := x0 + 1
	var z1 := z0 + 1
	return tri_interp(
		grid[z0 * w + x0], grid[z0 * w + x1],
		grid[z1 * w + x0], grid[z1 * w + x1],
		fx - x0, fz - z0)
