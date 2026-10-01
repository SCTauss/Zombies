extends RefCounted
## Events any role may emit. Shared contract (AGENTS.md §4).
## Names ending in `_requested` are requests: clients send them to the host
## (core/net/net.gd), and the authority decides whether to apply them.

const EVENTS: Array[StringName] = [
	&"resource_change_requested",  # {key, amount, reason}; sim applies it (MockRules on mock state)
	&"document_requested",  # {document_id, from_role, kind, data}; the Politician answers it
]
