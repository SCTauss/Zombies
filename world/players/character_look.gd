extends Node3D
## Cartoon "bean" body for a player character, one look per role (H-008, H-009).
## Built from primitives. The player script animates `body`, `arms` and `feet`.

const Toon := preload("res://world/fx/toon.gd")

const SKIN := Color(1.0, 0.80, 0.62)
const LOOKS := {
	"politician": {"body": Color(0.20, 0.26, 0.48), "name": "Politician", "tag": Color(0.55, 0.70, 1.0)},
	"military": {"body": Color(0.42, 0.52, 0.26), "name": "Military", "tag": Color(0.60, 0.85, 0.35)},
	"medic": {"body": Color(0.95, 0.95, 0.97), "name": "Medic", "tag": Color(1.0, 0.45, 0.45)},
	"labor": {"body": Color(1.0, 0.55, 0.15), "name": "Labor", "tag": Color(1.0, 0.80, 0.25)},
}

var role := "military"
var body: Node3D
var arms: Array[Node3D] = []
var feet: Array[Node3D] = []


static func display_name(role_id: String) -> String:
	return LOOKS[role_id]["name"]


static func tag_color(role_id: String) -> Color:
	return LOOKS[role_id]["tag"]


func _ready() -> void:
	var color: Color = LOOKS[role]["body"]
	body = Node3D.new()
	add_child(body)
	# Bean: one capsule, with a skin-colored face patch.
	var bean := CapsuleMesh.new()
	bean.radius = 0.42
	bean.height = 1.5
	Toon.part(body, bean, color, Vector3(0, 0.85, 0))
	var face := Toon.part(body, Toon.sphere(0.34), SKIN, Vector3(0, 1.22, -0.16), false)
	face.scale = Vector3(1.0, 0.85, 0.6)
	for side in [-1.0, 1.0]:
		var eye := Toon.part(body, Toon.sphere(0.085), Color.WHITE, Vector3(side * 0.13, 1.28, -0.36), false)
		Toon.part(eye, Toon.sphere(0.045), Color.BLACK, Vector3(0, 0, -0.06), false)
	Toon.part(body, Toon.box(Vector3(0.16, 0.035, 0.03)), Color(0.35, 0.12, 0.12), Vector3(0, 1.10, -0.37), false)
	# Arms swing from the shoulders; feet waddle.
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 0.45, 1.05, 0)
		body.add_child(pivot)
		var arm := CapsuleMesh.new()
		arm.radius = 0.11
		arm.height = 0.6
		Toon.part(pivot, arm, color.darkened(0.1), Vector3(0, -0.25, 0))
		Toon.part(pivot, Toon.sphere(0.12), SKIN, Vector3(0, -0.55, 0))
		arms.append(pivot)
		var foot := Toon.part(self, Toon.sphere(0.16), color.darkened(0.45), Vector3(side * 0.18, 0.1, 0))
		foot.scale = Vector3(1, 0.6, 1.4)
		feet.append(foot)
	_add_accessories(color)


func _add_accessories(color: Color) -> void:
	match role:
		"politician":
			Toon.part(body, Toon.box(Vector3(0.36, 0.40, 0.05)), Color(0.95, 0.95, 0.95), Vector3(0, 0.82, -0.40), false)
			Toon.part(body, Toon.box(Vector3(0.10, 0.36, 0.05)), Color(0.85, 0.10, 0.15), Vector3(0, 0.80, -0.43))
			Toon.part(body, Toon.cylinder(0.36, 0.05), Color(0.08, 0.08, 0.10), Vector3(0, 1.62, 0))
			Toon.part(body, Toon.cylinder(0.25, 0.45), Color(0.08, 0.08, 0.10), Vector3(0, 1.86, 0))
			Toon.part(body, Toon.cylinder(0.255, 0.08), Color(0.85, 0.10, 0.15), Vector3(0, 1.69, 0), false)
		"military":
			var helmet := Toon.part(body, Toon.sphere(0.47), color.darkened(0.35), Vector3(0, 1.5, 0.02))
			helmet.scale = Vector3(1, 0.55, 1)
			Toon.part(body, Toon.box(Vector3(0.55, 0.6, 0.3)), Color(0.45, 0.35, 0.22), Vector3(0, 0.95, 0.42))
		"medic":
			Toon.part(body, Toon.box(Vector3(0.28, 0.08, 0.05)), Color(0.90, 0.12, 0.18), Vector3(0, 0.85, -0.42), false)
			Toon.part(body, Toon.box(Vector3(0.08, 0.28, 0.05)), Color(0.90, 0.12, 0.18), Vector3(0, 0.85, -0.42), false)
			Toon.part(body, Toon.box(Vector3(0.36, 0.14, 0.06)), Color(0.55, 0.80, 0.95), Vector3(0, 1.12, -0.38), false)
			var cap := Toon.part(body, Toon.cylinder(0.30, 0.16), Color.WHITE, Vector3(0, 1.62, 0))
			cap.rotation.x = -0.15
		"labor":
			var hat := Toon.part(body, Toon.sphere(0.44), Color(1.0, 0.85, 0.10), Vector3(0, 1.52, 0))
			hat.scale = Vector3(1, 0.6, 1)
			Toon.part(body, Toon.cylinder(0.56, 0.05), Color(1.0, 0.85, 0.10), Vector3(0, 1.45, -0.04))
			Toon.part(body, Toon.cylinder(0.44, 0.12), Color(0.45, 0.28, 0.14), Vector3(0, 0.55, 0))
			Toon.part(body, Toon.box(Vector3(0.12, 0.3, 0.06)), Color(0.6, 0.6, 0.65), Vector3(0.3, 0.45, -0.36))
