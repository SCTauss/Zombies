extends Node3D
## The world API that role views use (docs/CONTRACTS.md, "View contract").
## The real camp (world/camp/camp_main.tscn) and each role's standalone
## <role>_main.tscn extend this, so a view works the same in both.
##
## Expected children (optional ones may be missing in a standalone scene):
##   CampGreybox, CameraRig (top-down), Buildings, Construction, WaveSpawner,
##   Towers (roles/military/tower_layer.gd), DefenseRules

@onready var map: Node3D = $CampGreybox
@onready var buildings: Node3D = get_node_or_null("Buildings")
@onready var construction: Node = get_node_or_null("Construction")
@onready var spawner: Node3D = get_node_or_null("WaveSpawner")
@onready var towers: Node3D = get_node_or_null("Towers")
@onready var defense_rules: Node = get_node_or_null("DefenseRules")
@onready var _top_down: Node3D = $CameraRig


## The top-down camera rig (world/camera/top_down_camera.gd) world views use.
func top_down_camera() -> Node3D:
	return _top_down
