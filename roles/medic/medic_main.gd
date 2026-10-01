extends Node
## Medic standalone scene (F6): the check-in desk on mock state, open right
## away. In the real game the camp opens it from the check-in desk station.

@onready var view: Node = $MedicView


func _ready() -> void:
	view.open_view(self)


## Dev / screenshot helper: examine the first survivor a bit.
func dev_demo() -> void:
	view.exam(0)
	view.exam(2)
