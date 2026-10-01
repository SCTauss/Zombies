extends Node
## Mock rules (autoload `MockRules`): a stand-in for sim/ (Lane B) so role
## scenes work alone on mock state. It applies `resource_change_requested`
## as-is (never below 0), with no real rules.
##
## Only active while CampState is mock and we're the authority.
## Lane B: once sim/ handles requests in mock mode too, set `enabled = false`.

var enabled := true


func _ready() -> void:
	EventBus.subscribe(&"resource_change_requested", _on_resource_change_requested)


func _on_resource_change_requested(payload: Dictionary) -> void:
	if not enabled or not CampState.is_mock or not CampState.is_authority():
		return
	var key: String = payload.get("key", "")
	var amount: Variant = payload.get("amount", 0)
	if key.is_empty() or not (amount is int or amount is float):
		push_warning("MockRules: bad resource_change_requested payload %s" % payload)
		return
	CampState.set_value(key, max(0, CampState.get_value(key, 0) + amount))
