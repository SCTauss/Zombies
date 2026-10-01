extends "res://world/camp/camp_base.gd"
## Military standalone scene (F6): a mock camp world with the Military view
## open right away. In the real game the camp opens the view from the
## command table (world/camp/camp_main.tscn).

@onready var view: Node = $MilitaryView


func _ready() -> void:
	view.open_view(self)


## Dev / screenshot helper.
func dev_demo() -> void:
	view.dev_demo()
