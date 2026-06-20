extends RefCounted
class_name GeomUtil
## Small shared geometry helpers.

## Merged bounding box of every MeshInstance3D under `root`, in `root`'s LOCAL space (for centring/fitting a model).
static func aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var stack: Array = [root]
	while stack.size() > 0:
		var n = stack.pop_back()
		if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
			var mi := n as MeshInstance3D
			var rel: Transform3D = root.global_transform.affine_inverse() * mi.global_transform
			var aa: AABB = rel * mi.get_aabb()
			if first:
				result = aa
				first = false
			else:
				result = result.merge(aa)
		for c in n.get_children():
			stack.append(c)
	return result
