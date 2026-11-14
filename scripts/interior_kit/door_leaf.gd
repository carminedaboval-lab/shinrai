extends AnimatableBody3D
## The swinging leaf of a kit door. A bullet's ray lands on the leaf, so the leaf is what the
## gun calls; it passes the hit to its door, which decides whether the lock was struck.


func receive_bullet_hit(damage: float, source: Node, at: Vector3, direction: Vector3) -> bool:
	var door := get_parent()
	if door == null or not door.has_method("bullet_hit"): return false
	return door.bullet_hit(damage, source, at, direction)
