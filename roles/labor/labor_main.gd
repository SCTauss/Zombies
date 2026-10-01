extends "res://world/camp/camp_base.gd"
## Labor standalone scene (F6): a mock camp world with the Labor view open
## right away. In the real game the camp opens the view from the workbench
## (world/camp/camp_main.tscn).

@onready var view: Node = $LaborView


func _ready() -> void:
	view.open_view(self)


## Dev / screenshot helper.
func dev_demo() -> void:
	view.dev_demo()
