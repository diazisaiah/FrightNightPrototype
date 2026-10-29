# Fright Night Character Lab

This is a playground-only third-person rig, animation, camera, skin-continuity, and multiplayer-presentation prototype for the six existing fighters. It does not change production combat, production saves, or add a new fighter.

## Launch and controls

Run `playground/run_playground.bat` on Windows, or `bash playground/run_playground.sh`. The launcher synchronizes production resources into the generated playground project before starting it. Never edit `playground/project/` directly.

- `F1`: show or hide the playground panel.
- `V`: switch between original first-person play and persistent third-person play.
- Controller Share/Misc button or PlayStation Touchpad: the same camera toggle when the device exposes one of those otherwise-unused inputs. Every standard face, shoulder, stick-click, D-pad, Start, and View button already has a production combat binding, so the panel's mode selector is the fallback on pads without Share/Touchpad reporting.
- Mouse or right stick: normal combat aim in third person. In Character Inspect, right-drag or right stick orbits the model.
- Mouse wheel or `Page Up` / `Page Down`: camera distance. Controller users can also adjust Distance with the panel's virtual cursor.
- The panel exposes centered/left/right shoulder offset, smoothing, camera-relative movement diagnosis, presentation-only movement/camera/target facing, HUD hiding, and front/three-quarter/side/back presets.

Changing fighter reloads the isolated playground because the production player class and ability objects change. Changing only skin is live: the production `PlayerBody` render instance and production `Fists` instance are replaced together while the semantic rig, active clip, normalized phase, player position, and combat state are retained.

## Character Lab workflow

Choose **Character inspect** in the Character Lab mode selector. Inspection freezes the production player and every node in the `enemies` group until fight mode returns. The lab includes:

- 0.25x, 0.5x, 1x, and 1.5x playback, loop, pause, restart, and next-clip controls;
- neutral studio and arena lighting, silhouette-only geometry, and one-draw skeleton/joint debug;
- default/alternate live split comparison locked to exactly the same clip and phase;
- undistorted default voxel, default art, alternate voxel, and alternate art references, including alternate references while the default skin is equipped;
- adjustable reference opacity and stable four-view PNG capture;
- relaxed, guard, left punch, right punch, open-hand, and ultimate-ready first-person hand/glove review poses;
- actual production-timed jab/cross/hook/uppercut buttons, separate from visual-only animation previews;
- one local avatar plus up to three differently configured simulated remote avatars.

**Capture 4 views** writes front, three-quarter, side, and back PNGs under `user://character_lab_captures/`. The six-character smoke gallery writes `rig_gallery_default.png` and `rig_gallery_alternate.png`; the dense art-review harness writes one neutral `single_review_<fighter>.png` at a time so close review does not require all six inspection meshes to be resident together.

## Rig and animation architecture

`fighter_avatar.gd` owns a stable 29-joint semantic hierarchy for every fighter:

- root, pelvis, spine, chest, neck, and head;
- left/right clavicle, upper arm, forearm, wrist, and hand;
- left/right thigh, shin, ankle, and foot;
- hair, beard, sash, and two headband-tail attachments.

The visible character is the actual production `PlayerBody`, instantiated directly from `res://player_body.gd`. No Character Lab approximation or replacement mesh is rendered. The lab's 29-joint semantic hierarchy remains an animation authoring layer: it combines its spine, clavicle, wrist, ankle, and attachment motion into the production body's existing hips, torso, head, shoulder, elbow, hip, and knee pivots. This preserves the exact in-game voxel sculpture, fighter proportions, face, hair, clothing, equipped hat, skin palette, and baked geometry while allowing the expanded boxing state machine to drive it. Silhouette mode applies to the real production geometry.

The deterministic state machine exposes 50 review states: relaxed/guard, forward/back/strafe/run, jump start/airborne/fall/land, turn and guard transitions, six punches, block/slips/rolls/back step/guard break, directional light and heavy hits, four knockdowns, both grounded orientations and both get-ups, two ultimate paths per fighter, and a personality taunt. Live locomotion blends from authoritative local velocity; preview locomotion remains inspectable even while simulation is frozen.

`play_action(command)` accepts compact replicated data rather than bone transforms. Supported fields include `action`, `hand`, `duration`, `impact_fraction`, `direction`, `severity`, `ultimate_id`, `started_at`, `received_at`, `normalized_phase`, `seek`, and `speed`. `apply_locomotion(state)` consumes local velocity, grounded state, amount, and optional facing yaw. Late commands seek from their timestamp. Stable `impact`, `charge`, `release`, `effect_end`, `ground_contact`, and `feet_planted` markers are exposed for future VFX/audio attachment; stale markers are not replayed after a late seek.

Simulation remains authoritative for position, hit validity, damage, invulnerability, knockback, and ultimate results. Secondary hair, sash, beard, and headband motion is local and cosmetic.

## Fighter and skin fidelity matrix

| Fighter | Bespoke third-person identity | Approved alternate | First-person continuity | Reference/glow path |
|---|---|---|---|---|
| Mauler | Extra-wide heavyweight proportions, huge mitts, planted guard, open vest, compact square hair | Obsidian Furnace | Production Mauler glove geometry rebuilt with the same skin ID | Default/alternate voxel and art; `Skins.palette()` glow |
| Answer | Lean waist, disciplined centerline guard, layered gi, compact squared hair | White Noise | Production banded wraps and compact hands | All four references; shared palette/glow source |
| Blur | Small coiled frame, cropped top, balloon trousers, angular layered hair | Hyperlight | Production finger/wrap rig and afterimage-capable punches | All four references; shared palette/glow source |
| Stray | Long mobile line, torn layers, outward hair/loc shapes, exactly two animated tails | Rooftop Ghost | Production fingerless/wrapped hands retain asymmetry | All four references; shared palette/glow source |
| Tony | Short stocky frame, cap/stubble/tracksuit silhouette, slouched expressive guard | Sunday Best | Production articulated five-finger hands support palm-up/open review | All four references; shared palette/glow source |
| Catalyst | Barrel chest, heavy forearms, large hair/beard mass, deliberate stance | Verdant Sigil | Production left/right rune groups and independent rune color behavior | All four references; shared palette/glow source |

All six visible bodies are the independently sculpted production bodies. Every alternate remains the same person and same silhouette; only the approved production palette, surface accents, and glow treatment change.

## Performance observation

`tests/four_avatar_performance.tscn` measures the real arena, not an empty model viewer. The earlier lightweight placeholder result is obsolete. The restored production voxel bodies currently report roughly 193K-238K rendered cube triangles per fighter in the single-character review. Re-run the arena probe before multiplayer migration and record draw, primitive, frame-time, FPS, LOD, and shadow-policy results here.

Run the observation again with:

```powershell
& $env:GODOT --path playground/project --scene res://playground/character_lab/tests/four_avatar_performance.tscn
```

It writes `four_avatar_performance.png` under the capture folder and prints hardware, FPS, draw, primitive, and authored model-triangle counts.

## Automated checks

- `tests/character_lab_regression.tscn`: all six fighters, 29 joints, 50 states, every reference path, alternate binding, phase-preserving skin changes, timestamp seeking, marker behavior, compact locomotion, silhouette, and skeleton debug.
- `tests/playground_integration.tscn`: real playground initialization, three camera modes, camera collision, real punch-start timing, inspect freeze/restore, three command-driven remotes, live first-person skin continuity, references, comparison, HUD, zoom, and hand poses.
- `tests/rig_gallery.tscn`: default and approved-alternate visual smoke galleries plus six stable close default-model captures.
- `tests/single_fighter_review.tscn`: hidden-window neutral render for one dense fighter at a time; accepts `-- --fighter <id>` and reports authored triangles.
- `tests/four_avatar_performance.tscn`: live four-avatar arena measurement and capture.

## Known limitations

- This is a reusable named rigid-pivot rig and procedural state machine, not yet a Godot `Skeleton3D` plus imported `AnimationPlayer` clip library. It proves the command contract, but a production art pass may author the same joint names as a formal skeleton.
- The visible models are the exact production `PlayerBody` sculptures. Fidelity limitations in the lab are therefore the same as the current game models, not a separate interpretation.
- Production `PlayerBody` has eleven coarse animation pivots. The lab preserves a richer 29-joint semantic contract, but wrist/hand motion is combined into the production elbow pivot and ankle/foot motion into the production knee pivot until the production body itself gains those extra pivots.
- Hands are the real production first-person rigs. A live skin change replaces their render instance because production `Fists` has no palette-rebind API; gameplay state and the third-person rig are not reloaded.
- Combat clips are procedural prototypes. They are readable and timing-aligned, but do not yet have hand-authored contact polish, IK foot locking, root-warping, motion matching, or mocap cleanup.
- Ground contact is posed, not ragdoll/physics driven. Secondary attachments use deterministic cosmetic sway.
- Simulated remotes validate commands, time seeking, and locomotion state only. There is no transport, server authority, prediction, rollback, lobby, or matchmaking code.
- Target locking changes only the displayed body's facing in this lab; it deliberately does not rewrite production targeting or movement.

## Production migration boundary

Everything authored for this prototype remains under `playground/src/character_lab/` plus playground documentation and panel wiring. Production migration would move the semantic animation adapter and command interface, extend or wrap the existing production `PlayerBody` pivots, expose a supported live `Fists` skin-rebind method, and serialize locomotion/actions through the eventual multiplayer layer. `player.gd` would continue to own simulation and publish authoritative action timestamps and impact fractions.

No transport code, production combat behavior, or production source file is changed by this lab.
