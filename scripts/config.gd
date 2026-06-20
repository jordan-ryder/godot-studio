extends Node
## Autoload singleton (registered as "Config"): shared editor constants.

const GRID_COLS := 500
const GRID_ROWS := 500
const WATER_LEVEL := 0.25

const GROUND_MATERIALS := ["grass", "dirt", "rock", "sand", "snow", "lava"]
const GROUND_COLORS := [
	Color(0.30, 0.52, 0.24),
	Color(0.45, 0.34, 0.22),
	Color(0.47, 0.46, 0.45),
	Color(0.80, 0.74, 0.52),
	Color(0.93, 0.95, 0.98),
	Color(0.92, 0.32, 0.10),
]

## Albedo color for a painted material index (clamped to the palette).
static func ground_color(i: int) -> Color:
	return GROUND_COLORS[clampi(i, 0, GROUND_COLORS.size() - 1)]

const PHYS_TERRAIN := 1 << 0
const PHYS_BUILDING := 1 << 1
const PHYS_SETPIECE := 1 << 7
