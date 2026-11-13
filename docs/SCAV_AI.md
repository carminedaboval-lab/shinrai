# Scav crew AI: how it thinks, and how to test it

Written 2026-11-13. The scav crew is the three-person human enemy (leader, scout, rear guard). This page says what they do, what was changed to make them act smarter, the measured before and after, and how to re-run the measurements in about 20 seconds.

## The test yard

Trying an AI change in the park costs a full park boot. The test yard does not:

- `scripts/test_yard/yard_world.gd`: 90 m of flat ground with plain cover of real sizes (house-sized blocks, head-high walls, waist-high walls, crates, car-sized blocks). Plain grey on purpose: it is a test room, not art.
- `scripts/test_yard/yard_navigation.gd`: a one-metre walk grid with the calls the crew needs.
- `scripts/test_yard/yard_raid.gd`: stands in for `extraction_run.gd` (player, phase, routes, gunfire).
- `tests/ai_probe_target.gd`: a scripted stand-in for the player.
- `tests/probe_scav_ai.gd`: plays nine situations at a fresh crew and prints timings.

Run it once (headless, no graphics card, about 20 s):

```powershell
.\tools\godot_locked.ps1 -Out reports\ai\run.txt -GodotArgs "--headless --path . --fixed-fps 60 --script res://tests/probe_scav_ai.gd -- --rows"
```

Run it five times and print the averages:

```powershell
powershell -File tools\ai\run_scav_probe.ps1 -Runs 5 -Tag after
```

Flags after `--`: `--only=open_fight,gone` runs just those; `--rows` prints what each scav is doing every second; `--why` prints, for a scav that can see the player, exactly what is stopping it from firing.

The nine situations: `walk_up`, `aimed_at`, `open_fight`, `break_contact`, `gone`, `unseen_shot`, `far_shot`, `sniped`, `sneak_behind`.

## What was wrong (measured before any change)

- **Nobody shot back.** After the player fired first at 22 m, all three walked to cover before anyone fired: 8.1 s to the first return shot on average.
- **One of the three often never fired.** Its eyes (1.5 m up) saw over a car or crate, but an aimed rifle's muzzle is only about 1.0 m up, so its own cover stopped every shot. The planner checked firing spots at 1.2 m, which is wrong for this model.
- **A flanker walked in plain view at 10–16 m without shooting.**
- **A scav kneeling to shoot blocked a crewmate's route**, and both stayed stuck.
- **Losing the player ended the fight.** They peeked at the empty spot for 14 s, walked in a clump to it, looked for 4 s and went back to strolling, 24 s after losing sight. The "search where he was heading" code existed but never ran.
- **Gunfire was all or nothing.** Inside 65 m they knew the shooter's spot to within 2.5 m, even through a building. Beyond 65 m they did not react at all.

## What they do now

1. **Fire and movement.** On contact, one member who can see the enemy shoots (kneeling beyond 8 m) for two to three seconds while the others get to cover. Never two at once, and they get down if rounds come back.
2. **Firing spots where the rifle clears.** Peek spots and side-steps are checked at muzzle height and a little under it (`fire_lane`). A shooter whose rifle is blocked for half a second steps further out along the cover, or finds other cover.
3. **Shooting back on the move.** Someone walking to cover who gets a clear look inside 32 m stops for a burst. A flanker who gets a clean look inside 16 m stops flanking and uses it.
4. **A steadier rhythm up close.** The pause between bursts is 1.0–1.6 s inside 30 m (it was 1.5–2.2 s). A shooter who was in the fight in the last 8 s picks the target up again in 0.15 s.
5. **Walking round each other** instead of pushing into a crewmate who is kneeling to shoot.
6. **The hunt.** Five seconds after anyone last saw the enemy, the crew stops watching the empty spot. It lists places to check: the last seen point, then rings 6, 12, 19 and 27 m out, leaning the way the enemy was heading and preferring places it cannot see from where it stands. Two walk the list with rifles up; one stays back on overwatch (the worst hurt, otherwise the rear guard). A place is ticked off when someone stands on it or plainly looks at it from close by. After about 55 s, or when every place is checked, they kneel and watch for 18 s, then go back to their routine. Seeing or being hit by the enemy ends the hunt at once; a new noise moves it there.
7. **Finding an angle.** A scav crouched somewhere with no view while the others fight walks to the nearest spot its rifle can reach the enemy from.
8. **Gunfire by distance.** The further away a noise, the rougher the guess at where it came from; more shots from the same place narrow it. Shots 65–220 m away make the crew stop, kneel and face that way for 14–20 s ("Shots, north-west. Heads up."), without turning hostile. For 90 s afterwards they warn a stranger off from 34 m instead of 20 m.

They still never know where the player is unless someone saw, heard or was hit. Radio reports guide movement only; a shot always needs the shooter's own eyes and a clear lane.

## Before and after (five runs each, test yard)

| Situation | Measure | Before | After |
|---|---|---|---|
| Player shoots first at 22 m, then stands still 30 s | First return shot | 8.1 s (0.8–13.2) | 0.8 s (every run) |
| | First hit on the player | 7.6 s, never in 1 run of 5 | 1.5 s |
| | Rounds fired by the crew | 23 | 40 |
| | Scavs who fired nothing in a run | up to all three | none |
| | Hits on the player | 6 | 14 |
| | Share of time exposed to the player | 0.56 | 0.53 |
| Player aims at them from 16 m | Hostile to first shot | 1.6 s | 0.8 s |
| Player ignores "Back off" and keeps walking in | Hits in the next 10 s | 6 | 11 |
| Player slips behind a building and sneaks off | Crew finds the player again | never | every run, 23–47 s after losing them |
| Player vanishes completely | Places searched | none | about 32 listed, two searching, one on overwatch |
| | Back to routine after | 23 s | 78 s |
| Unseen shot from 44 m behind a building | Crew finds the shooter after | 16.5 s | 14.8 s |
| One shot 75 m away | Reaction | none | all three kneel and watch within about 5° of the true direction for about 17 s |

Unchanged on purpose: walking up with the gun down still gets a warning at about 17 m and hostility 1.8 s later if ignored.

**They are deadlier up close.** A player who stands still in the open now takes about twice the hits. If that is too much, the knob is the burst pause (`attack_cooldown` in `scripts/scav_enemy.gd`, the `randf_range(1.0,1.6)`).

## Known limits

- The yard is flat with box cover. The park has a 4 m walk grid, slopes, plants that hide people, and the town streets; behaviour there can differ.
- Callouts during the hunt are captions over the speaker's head only.
- The gun pose itself is low (muzzle about 1.0 m when aimed). Raising the rifle to the shoulder is an animation job; the planner now works with the pose as it is.
- Police drones and midges were not touched.

## Files

- `scripts/scav_tactics.gd`: the shared planner (cover, peeks, flank, covering fire, the hunt).
- `scripts/scav_enemy.gd`: one scav (senses, aim, firing, movement).
- `scripts/scav_squad.gd`: the crew (warnings, hostility, morale, gunfire heard).
