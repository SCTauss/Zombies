extends Node3D
## A role's station in the camp (H-009). The role's player walks up to it and
## presses E to open that role's view. Cartoon props per role; a ring lights
## up while a player is in range.

const Toon := preload("res://world/fx/toon.gd")
const CampMap := preload("res://world/camp_greybox.gd")
const CharacterLook := preload("res://world/players/character_look.gd")

const HALF := Vector2(1.2, 0.8)  # footprint half extents
const RANGE := 2.6
const TITLES := {
	"politician": "Office desk",
	"military": "Command table",
	"medic": "Check-in desk",
	"labor": "Workbench",
}

@export var role := "military"

var highlighted := false:
	set(value):
		highlighted = value
		if _ring:
			_ring.visible = value

var _ring: MeshInstance3D


static func title(role_id: String) -> String:
	return TITLES[role_id]


func _ready() -> void:
	add_to_group(&"stations")
	_build_props()
	var body := StaticBody3D.new()
	body.add_to_group(CampMap.NAV_SOURCE_GROUP)
	var shape := CollisionShape3D.new()
	shape.shape = BoxShape3D.new()
	shape.shape.size = Vector3(HALF.x * 2.0, 1.0, HALF.y * 2.0)
	shape.position.y = 0.5
	body.add_child(shape)
	add_child(body)
	_ring = MeshInstance3D.new()
	_ring.mesh = Toon.cylinder(RANGE, 0.03)
	_ring.material_override = Toon.unshaded(Color(CharacterLook.tag_color(role), 0.25))
	_ring.position.y = 0.02
	_ring.visible = false
	add_child(_ring)
	var board := Label3D.new()
	board.text = "%s\n%s" % [CharacterLook.display_name(role).to_upper(), title(role)]
	board.modulate = CharacterLook.tag_color(role)
	board.outline_modulate = Color(0.08, 0.06, 0.10)
	board.outline_size = 14
	board.font_size = 48
	board.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	board.position.y = 2.6
	add_child(board)


func in_range(pos: Vector3) -> bool:
	return Vector2(pos.x - global_position.x, pos.z - global_position.z).length() <= RANGE


func _build_props() -> void:
	var wood := Color(0.72, 0.48, 0.28)
	# A table: top + four legs.
	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			Toon.part(self, Toon.box(Vector3(0.12, 0.85, 0.12)), wood.darkened(0.2), Vector3(x * 1.0, 0.42, z * 0.6))
	match role:
		"military":
			Toon.part(self, Toon.box(Vector3(2.4, 0.12, 1.6)), wood, Vector3(0, 0.9, 0))
			Toon.part(self, Toon.box(Vector3(2.1, 0.02, 1.3)), Color(0.85, 0.80, 0.55), Vector3(0, 0.97, 0), false)
			for pin in [[Vector3(-0.6, 0, -0.3), Color(0.9, 0.2, 0.2)], [Vector3(0.4, 0, 0.2), Color(0.2, 0.4, 0.9)], [Vector3(0.7, 0, -0.4), Color(0.9, 0.2, 0.2)]]:
				Toon.part(self, Toon.box(Vector3(0.03, 0.3, 0.03)), Color(0.2, 0.2, 0.2), pin[0] + Vector3(0, 1.12, 0), false)
				Toon.part(self, Toon.box(Vector3(0.18, 0.12, 0.02)), pin[1], pin[0] + Vector3(0.09, 1.22, 0), false)
			Toon.part(self, Toon.box(Vector3(0.5, 0.35, 0.3)), Color(0.30, 0.35, 0.25), Vector3(-0.8, 1.15, 0.45))
			Toon.part(self, Toon.box(Vector3(0.03, 0.6, 0.03)), Color(0.15, 0.15, 0.15), Vector3(-0.65, 1.6, 0.45), false)
		"labor":
			Toon.part(self, Toon.box(Vector3(2.4, 0.15, 1.6)), wood, Vector3(0, 0.9, 0))
			Toon.part(self, Toon.box(Vector3(1.2, 0.02, 0.9)), Color(0.25, 0.45, 0.85), Vector3(-0.3, 0.99, 0), false)
			Toon.part(self, Toon.box(Vector3(0.6, 0.35, 0.35)), Color(0.85, 0.15, 0.15), Vector3(0.75, 1.15, 0.3))
			Toon.part(self, Toon.box(Vector3(0.08, 0.08, 0.5)), Color(0.45, 0.30, 0.15), Vector3(0.6, 1.02, -0.4))
			Toon.part(self, Toon.box(Vector3(0.25, 0.12, 0.12)), Color(0.55, 0.55, 0.6), Vector3(0.6, 1.04, -0.65))
		"politician":
			Toon.part(self, Toon.box(Vector3(2.4, 0.15, 1.6)), Color(0.45, 0.25, 0.15), Vector3(0, 0.9, 0))
			for i in 3:
				Toon.part(self, Toon.box(Vector3(0.45, 0.12 + i * 0.08, 0.6)), Color(0.97, 0.97, 0.92), Vector3(-0.7 + i * 0.5, 1.03 + i * 0.04, -0.2))
			Toon.part(self, Toon.cylinder(0.1, 0.25), Color(0.85, 0.10, 0.15), Vector3(0.8, 1.1, 0.3))
			Toon.part(self, Toon.box(Vector3(0.05, 1.8, 0.05)), Color(0.75, 0.65, 0.30), Vector3(1.4, 0.9, 0.8))
			Toon.part(self, Toon.box(Vector3(0.6, 0.4, 0.03)), Color(0.20, 0.35, 0.75), Vector3(1.72, 1.6, 0.8))
		"medic":
			Toon.part(self, Toon.box(Vector3(2.4, 0.12, 1.6)), Color(0.92, 0.94, 0.96), Vector3(0, 0.9, 0))
			Toon.part(self, Toon.box(Vector3(0.4, 0.02, 0.55)), Color(0.75, 0.55, 0.35), Vector3(-0.5, 0.97, 0), false)
			Toon.part(self, Toon.box(Vector3(0.3, 0.3, 0.3)), Color(0.95, 0.95, 0.95), Vector3(0.6, 1.12, 0.3))
			Toon.part(self, Toon.box(Vector3(0.05, 1.6, 0.05)), Color(0.6, 0.6, 0.65), Vector3(-1.3, 0.8, 0.8))
			Toon.part(self, Toon.box(Vector3(0.6, 0.6, 0.04)), Color.WHITE, Vector3(-1.3, 1.75, 0.8))
			Toon.part(self, Toon.box(Vector3(0.45, 0.12, 0.05)), Color(0.9, 0.12, 0.18), Vector3(-1.3, 1.75, 0.77), false)
			Toon.part(self, Toon.box(Vector3(0.12, 0.45, 0.05)), Color(0.9, 0.12, 0.18), Vector3(-1.3, 1.75, 0.77), false)
