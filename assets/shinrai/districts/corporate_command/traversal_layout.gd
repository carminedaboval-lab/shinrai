extends RefCounted
## Shared metre-based contract for the standalone playable building.
const FLOORS: Array[float] = [0.8, 17.12, 20.62, 24.12, 39.12, 43.12, 47.12, 51.28]
const LABELS: Array[String] = ["Ground lobby", "Middle 1", "Middle 2", "Middle 3", "Upper 1", "Upper 2", "Upper 3", "Roof"]
const STAIR_LEVELS: Array[float] = [0.8, 4.88, 8.96, 13.04, 17.12, 20.62, 24.12, 27.87, 31.62, 35.37, 39.12, 43.12, 47.12, 51.28]
const CORE_CENTRES: Array[float] = [-4.25, 4.25]
const LIFT_CENTRE := Vector3(0.0, 0.0, -0.25)
const LADDER_X := -10.0
const LADDER_Z := -18.6
const LADDER_BOTTOM := 0.8
const LADDER_TOP := 51.28
