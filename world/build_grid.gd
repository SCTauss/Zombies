extends RefCounted
## Placement snapping shared by Military and Labor.
## O-13 (grid or freeform building) is open, so both modes exist: G toggles.

const CELL := 2.0

static var enabled := true


## Snap a ground point to the center of its grid cell (or just flatten it to y = 0).
static func snap(pos: Vector3) -> Vector3:
	if not enabled:
		return Vector3(pos.x, 0, pos.z)
	return Vector3((floorf(pos.x / CELL) + 0.5) * CELL, 0, (floorf(pos.z / CELL) + 0.5) * CELL)
