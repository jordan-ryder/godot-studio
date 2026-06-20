extends Node3D
class_name WaterSim

const TICK := 0.1
const SRC_LEVEL := 24
const MAX_CELLS_PER_SRC := 2500  # cliff-fall safety: never flood an ocean

var height_fn: Callable
var solid_fn: Callable
var physics_mask := 0
var _box_shape: BoxShape3D = null
var _phys_cache := {}

var _sources := {}
var _cells := {}
var _meshes := {}
var _frontier: Array = []
var _budget := {}
var _t := 0.0
var _mat: StandardMaterial3D = null

func setup(hf: Callable, sf: Callable) -> void:
	height_fn = hf
	solid_fn = sf
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.25, 0.5, 0.85, 0.62)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.emission_enabled = true
	_mat.emission = Color(0.15, 0.35, 0.6)
	_mat.emission_energy_multiplier = 0.4
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

static func cell_of(pos: Vector3) -> Vector3i:
	return Vector3i(int(floor(pos.x)), int(floor(pos.y)), int(floor(pos.z)))

func add_source(cell: Vector3i) -> void:
	_sources[cell] = true
	_budget[cell] = MAX_CELLS_PER_SRC
	_set_cell(cell, SRC_LEVEL, cell)

func remove_source(cell: Vector3i) -> void:
	_sources.erase(cell)
	_budget.erase(cell)
	_recompute()

func clear() -> void:
	_sources.clear()
	_recompute()

## Re-flood from scratch (file load / block change).
func _recompute() -> void:
	for c in _meshes:
		if is_instance_valid(_meshes[c]): _meshes[c].queue_free()
	_meshes.clear()
	_cells.clear()
	_frontier.clear()
	_phys_cache.clear()
	for s in _sources:
		_budget[s] = MAX_CELLS_PER_SRC
		_set_cell(s, SRC_LEVEL, s)

func tick(delta: float) -> void:
	_t -= delta
	if _t > 0.0 or _frontier.is_empty():
		return
	_t = TICK
	var work := _frontier
	_frontier = []
	for item in work:
		_expand(item["cell"], int(item["level"]), item["src"])

func _blocked(cell: Vector3i) -> bool:
	if solid_fn.call(cell):
		return true
	if float(height_fn.call(cell.x + 0.5, cell.z + 0.5)) > float(cell.y) + 0.5:
		return true
	return _solid_physics(cell)

## Physics-shell solidity (cave roofs etc.). Needs a SHAPE query — point queries pass through hollow trimeshes.
func _solid_physics(cell: Vector3i) -> bool:
	if physics_mask == 0:
		return false
	if _phys_cache.has(cell):
		return _phys_cache[cell]
	if _box_shape == null:
		_box_shape = BoxShape3D.new()
		_box_shape.size = Vector3(0.9, 0.9, 0.9)
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _box_shape
	q.transform = Transform3D(Basis(), Vector3(cell.x + 0.5, cell.y + 0.5, cell.z + 0.5))
	q.collision_mask = physics_mask
	q.collide_with_areas = false
	var solid := not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()
	_phys_cache[cell] = solid
	return solid

func _expand(cell: Vector3i, level: int, src: Vector3i) -> void:
	if int(_budget.get(src, 0)) <= 0:
		return
	var below := cell + Vector3i(0, -1, 0)
	if not _blocked(below) and int(_cells.get(below, 0)) < SRC_LEVEL and below.y > -40:
		_set_cell(below, SRC_LEVEL, src)
		return
	var next := level - 1
	if next < 1:
		return
	for d in [Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		var n: Vector3i = cell + d
		if _blocked(n):
			continue
		if int(_cells.get(n, 0)) >= next:
			continue
		_set_cell(n, next, src)

func _set_cell(cell: Vector3i, level: int, src: Vector3i) -> void:
	var had := int(_cells.get(cell, 0))
	if had >= level:
		return
	_cells[cell] = level
	if had == 0:
		_budget[src] = int(_budget.get(src, 0)) - 1
	_frontier.append({"cell": cell, "level": level, "src": src})
	_render_cell(cell, level)

func _render_cell(cell: Vector3i, level: int) -> void:
	var mi: MeshInstance3D = _meshes.get(cell)
	if mi == null or not is_instance_valid(mi):
		mi = MeshInstance3D.new()
		mi.material_override = _mat
		add_child(mi)
		_meshes[cell] = mi
	var h := 0.92 * float(level) / float(SRC_LEVEL)
	var bm := BoxMesh.new()
	bm.size = Vector3(1.0, h, 1.0)
	mi.mesh = bm
	mi.position = Vector3(cell.x + 0.5, cell.y + h * 0.5, cell.z + 0.5)

func notify_blocks_changed() -> void:
	_recompute()
