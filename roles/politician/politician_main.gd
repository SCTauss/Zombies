extends Node
## Politician standalone scene (F6): the office desk on mock state, open right
## away. In the real game the camp opens it from the office desk station.

@onready var view: Node = $PoliticianView


func _ready() -> void:
	view.open_view(self)


## Dev / screenshot helper.
func dev_demo() -> void:
	view.show_tab(0)
