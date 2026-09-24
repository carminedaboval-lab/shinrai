# Extraction route review

This change starts from `codex/k17-drone-integration` at `a4b3375` and touches only extraction scripts and extraction tests. The K17 model is still absent. No new assets are included. Park, lake, vegetation, and lighting scripts are untouched.

## Changes to check

- A new deployment restores the player collision layer and mask if the preceding run ended during a mantle. The initial HUD values also appear immediately.
- Guidance now chooses a reachable navigation cell inside a relay's interaction distance or an extraction gate's zone. The HUD states when no route is found. The field map uses one scale on both axes, marks the gate zones, and labels gates locked or open.
- Settlement failure keeps the result pending and offers a retry on the result screen. Credits and cargo are not shown as banked until a save succeeds. Temporary save failures can be retried in operations. Invalid saves are left intact, stash counts reload as integers, and a second deployment cannot replace an unsettled run.

## Automated checks and desktop validation

1. `godot --headless --path . --script res://tests/test_extraction_regressions.gd`
2. `godot --headless --path . --script res://tests/test_extraction.gd`
3. `godot --headless --path . --script res://tests/test_extraction_walk.gd` and again with `-- --west`. The walking test uses movement and interaction input without teleporting; on a snag it prints the player's position and slide collider. It uses its own QA save and deletes that save when it finishes.
4. Launch F5 in the editor and manually walk from South insertion to a relay, hold E, then walk to South Gate and stay inside its marked zone for 15 seconds. Repeat with West Gate. Check that the camera, collision, relay interaction, countdown and result feel correct. The automated walk helps pinpoint a snag but does not replace this manual pass.
5. In the map, click a relay and each exit. Verify the route, player facing, gate labels and true gate-zone rings. Check initial HUD, pause/resume clock, recovery after a failed save, stash after extraction and stash after interrupted/dead runs. Inspect the editor debugger for warnings.

GitHub Actions with Godot 4.7.1 passed the lightweight save/navigation/map regressions, the complete extraction integration test (`0 failures`), and the input-driven South and West walks. Both walks recovered the South garden relay and extracted at their respective gate using movement input, normal collision, and Hold E. The [passing full-park run](https://github.com/carminedaboval-lab/shinrai/actions/runs/36021127710) also captured HQ, gameplay HUD, and field-map PNGs as an artifact. The workspace disconnected before I could inspect those PNGs, so rendered visual review remains pending. Scripted movement does not replace a manual first-person playthrough.

The desktop manual pass remains pending because this workspace has no direct access to the user's Godot editor. This PR stays draft until that pass is complete. The K17 combat pass remains pending the user-supplied model.
