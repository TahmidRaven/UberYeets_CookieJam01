class_name MeshUtils
extends RefCounted

# Measures a node's visual bounds in its own local space by walking every
# VisualInstance3D beneath it, so callers get the real footprint/height of
# whatever mesh is actually there instead of a hand-entered guess.
static func local_aabb(root: Node3D) -> AABB:
	var root_inverse: Transform3D = root.global_transform.affine_inverse()
	var result := AABB()
	var found := false
	var stack: Array[Node] = [root]

	while not stack.is_empty():
		var current: Node = stack.pop_back()

		if current is VisualInstance3D:
			var mesh_aabb: AABB = current.get_aabb()
			var local_transform: Transform3D = root_inverse * current.global_transform
			var transformed := _transform_aabb(mesh_aabb, local_transform)
			if found:
				result = result.merge(transformed)
			else:
				result = transformed
				found = true

		for child in current.get_children():
			stack.append(child)

	return result

static func _transform_aabb(aabb: AABB, t: Transform3D) -> AABB:
	var result: AABB
	for i in 8:
		var corner := aabb.position + Vector3(
			aabb.size.x if (i & 1) else 0.0,
			aabb.size.y if (i & 2) else 0.0,
			aabb.size.z if (i & 4) else 0.0
		)
		var transformed_corner: Vector3 = t * corner
		if i == 0:
			result = AABB(transformed_corner, Vector3.ZERO)
		else:
			result = result.expand(transformed_corner)
	return result
