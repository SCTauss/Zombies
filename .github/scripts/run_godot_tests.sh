#!/usr/bin/env bash
# Runs every test scene under tests/ headless. Used by CI; works locally too:
#   GODOT=/path/to/godot bash .github/scripts/run_godot_tests.sh
#
# Conventions (both lanes):
#   tests/<lane>/*_smoke.tscn   runs alone and must exit 0.
#   tests/<lane>/net_*.tscn     runs as a pair: --role=host and --role=client.
# A run also fails if Godot prints "SCRIPT ERROR" (broken script anywhere).

set -uo pipefail

GODOT=${GODOT:-godot}
TIMEOUT=${TEST_TIMEOUT:-300}
LOG_DIR=$(mktemp -d)
failed=()

run_one() {  # name, log file, godot args...
	local name=$1 log=$2
	shift 2
	timeout "$TIMEOUT" "$GODOT" --headless --path . "$@" >"$log" 2>&1
	local code=$?
	cat "$log"
	if [[ $code -ne 0 ]]; then
		echo "::error::$name exited with $code"
		return 1
	fi
	if grep -q "SCRIPT ERROR" "$log"; then
		echo "::error::$name printed SCRIPT ERROR"
		return 1
	fi
	return 0
}

shopt -s nullglob
for scene in tests/*/*_smoke.tscn; do
	name=$(basename "$scene" .tscn)
	res="res://$scene"
	echo "::group::$scene"
	if [[ $name == net_* ]]; then
		run_one "$name host" "$LOG_DIR/$name.host.log" "$res" -- --role=host &
		host_pid=$!
		sleep 2
		run_one "$name client" "$LOG_DIR/$name.client.log" "$res" -- --role=client || failed+=("$scene (client)")
		wait "$host_pid" || failed+=("$scene (host)")
	else
		run_one "$name" "$LOG_DIR/$name.log" "$res" || failed+=("$scene")
	fi
	echo "::endgroup::"
done

if [[ ${#failed[@]} -gt 0 ]]; then
	echo "Failed tests:"
	printf '  %s\n' "${failed[@]}"
	exit 1
fi
echo "All tests passed."
