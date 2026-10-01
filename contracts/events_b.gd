extends RefCounted
## Events Lane B (sim, citizens, UI, Politician, Medic) emits. Shared contract:
## additions are fine, renames/removals need Lane A's OK (AGENTS.md §4).
## Payloads are plain Dictionaries; the expected keys are listed per event.

const EVENTS: Array[StringName] = [
	# sim: citizens and survivors
	&"survivor_arrived",  # {citizen}
	&"citizen_infected",  # {citizen_id}
	&"citizen_turned",  # {citizen_id}
	&"citizen_died",  # {citizen_id, cause}
	# Medic
	&"survivor_admitted",  # {citizen_id}
	&"survivor_rejected",  # {citizen_id}
	&"survivor_quarantined",  # {citizen_id}
	&"research_completed",  # {research_id}
	# Politician
	&"budget_allocated",  # {budget: {role: amount}}
	&"policy_enacted",  # {policy_id}
	&"policy_revoked",  # {policy_id}
	&"document_signed",  # {document_id, from_role}
	&"document_rejected",  # {document_id, from_role}
	&"judgment_issued",  # {case_id, citizen_id, verdict}
	# run end (see O-08)
	&"run_ended",  # {reason}
]
