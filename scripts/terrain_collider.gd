extends Object
class_name TerrainCollider
## Terrain heightfield collider recipe (editor character mode).

static func build(heights: PackedFloat32Array, w: int, d: int) -> Array:
	var shape := HeightMapShape3D.new()
	shape.map_width = w
	shape.map_depth = d
	shape.map_data = heights
	var body := StaticBody3D.new()
	body.name = "GroundCollider"
	body.collision_layer = Config.PHYS_TERRAIN
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	body.position = Vector3((w - 1) * 0.5, 0.0, (d - 1) * 0.5)
	return [body, shape]
