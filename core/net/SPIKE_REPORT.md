# Networking spike report (Phase 0, Lane A)

Input for **O-03** (networking model). The owner decides; this is Lane A's recommendation.

## What was built
- `core/net/net.gd` (autoload `Net`, PROTOTYPE): listen-server over ENet, Godot's
  built-in high-level multiplayer. No addons.
- Host = authority (peer id 1). Offline play runs the same code with no peer.
- **State:** the host sends a full `CampState` snapshot when a peer joins, then
  each changed key (reliable RPC). Clients never write state; `CampState.set_value`
  refuses on non-authority peers.
- **Events:** the host forwards every event it emits to clients, except requests.
  Clients forward only `*_requested` events to the host, which re-emits them with
  `peer_id` in the payload. So the contracts' "clients request, authority applies"
  rule holds over the network with no extra code in role scenes.
- `core/dev/net_spike.tscn`: manual test (two windows, Host / Join).
- `tests/a/net_smoke.tscn`: automated two-process test (see the script header).

## Results (Godot 4.7.2, Windows, localhost)
- Join → snapshot → value sync → event relay → client request applied by the
  host and synced back: **works**. Both processes exit 0.
- Late join is free: a joining peer gets the full snapshot.
- Camp state is small and changes slowly, so per-key reliable updates are enough.

## Limits found
- **Internet play:** plain ENet needs the host to open UDP port 24680 (router
  port forwarding), or both players on a VPN like Tailscale or ZeroTier. No NAT
  punch-through built in.
- Real-time 3D (zombies, player avatars, if O-05 adds them) will need
  `MultiplayerSynchronizer` / unreliable updates. Not tested yet; Phase 3 work.
- No host migration: if the host leaves, the run ends for everyone.
- No validation or rate limiting on requests yet. The host (sim, Lane B) must
  validate every `*_requested` payload before applying it.
- Only tested on one machine (localhost). Needs a real two-PC test.

## Recommendation for O-03
1. **Listen-server, host authority** (what the spike does). A dedicated server
   adds hosting cost and isn't needed for 1–4 player co-op.
2. **ENet for development and LAN** now. Keep the transport swappable inside `Net`.
3. **Steam relay later** if the game ships on Steam (ties into O-10). That needs
   the GodotSteam addon, which is an owner decision (new dependency).
4. Until then, playtest over the internet with Tailscale/ZeroTier or port forwarding.
