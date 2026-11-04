# Drag-strip presentation validation

## Implemented

The former city-street backdrop is replaced by a shared drag-facility renderer for desktop and portrait. Five original SVG layers provide day/night skies, textured asphalt, grandstands/crowds and concrete barriers. Procedural rubber tracks, repairs, lane edges, floodlights, a world-mounted Christmas tree, starting beams, a finish stripe and timing board use the same track-space distance. The three existing careers select reusable daylight/nighttime presentation configurations; surface grip and racing rules do not change by venue.

The existing static vehicle renderer, wheels and customization remain. Wheel highlights/blur still use actual angular speed, including burnout slip. Night paint/glass lighting, headlight spill and brake lights follow the scene and actual brake input/force. Loaded shifts add restrained body movement; camera acceleration/braking response is smoothed without moving HUD controls. Existing limited smoke, idle vibration, pitch and exhaust effects remain simulation-driven. Optional high-speed road streaks are short procedural marks, not a full-screen blur pass.

EngineVoice remains the primary audio source. The same generator now mixes quiet original track/wind/crowd synthesis and event-driven amber, green, foul and finish cues. Tire slip, turbo, exhaust and drivetrain sounds continue using the original coupled engine voice. Red lanes suppress green/victory cues; muted and paused effects fade without stale cues or repeated triggers. No protected recording or reference art was reused.

## Staging and timing

- Assisted staging is the default, preserving the previous held start and existing keyboard/touch behavior. The Stage button during countdown enables manual staging for that session. It does not change installed transmission hardware or reset the car's position.
- Cars are initially placed shallow-staged. Manual staging enables the existing torque/clutch/converter/traction solver before green while the official race clock stays stopped. Brake/clutch/transbrake release can physically clear the stage beam early. Converter coupling remains active during manual staging; a dedicated regression catches accidental neutralization.
- White pre-stage/stage indicators read actual distance. The beam model uses an explicit 25 mm detector-height approximation, a tire-chord rollout derived from installed tire radius, and 0.18 m spacing. These are game approximations, not recovered reference parameters or a claim of sanctioning-body compliance. Reverse staging maneuvers and separate front/rear tire physics are not added.
- A fixed three-second start includes a staged hold followed by three half-second amber intervals. Both the tree and sound derive their phase from this same physics countdown. Pause freezes it.
- Reaction time is interpolated at stage-beam clearance relative to green. Negative clearance time latches a red light. Clean displayed ET equals green-to-finish total minus beam reaction. Results show ET, signed reaction, trap speed, opponent performance, pay and XP. The existing green-to-finish clock still determines finish order, and historical best records retain that basis, now labeled Best 1/4 Total.
- Red-light runs are disqualified regardless of crossing order. They lose the committed stake and award no purse, XP, wins, career progress or best time. They can complete the physical pass and return through the existing results/retry flow. Duplicate settlement remains blocked.
- Opponent trap speed is frozen by interpolation at its own crossing rather than sampled later during rollout. The existing 0.55-second player finish rollout and recorded crossing values are preserved.

## Validation

Final results: all **29 regression entries** passed, followed by **20 clean-package checks** from a new extraction without editor cache or prior saves. The new staging/audio test passed **22,084 checks**. Canonical green-to-finish physics fixtures remain **13.2193 s / 109.8525 mph** stock and **10.0011 s / 151.6064 mph** upgraded, with no safety clamps. These legacy fixture times are not relabeled as beam ET. Live audio recorded zero steady-state underruns at all four tested caps; 16 startup/prior underruns were logged separately in this Windows run.

The complete suite covers all existing physics, 2–10-speed transmissions, 204 transmission comparisons, upgrades, original audio, AI, career/economy, saves, appearance, real input routing, responsive UI, race flow and graceful shutdown. New staging checks exercise beam geometry, negative/positive reaction, ET arithmetic, countdown phases, five transmission families, pre-start converter motion, physical brake-held burnout and smoke, pause/mute/cue continuity and disqualification audio.

Graphical checks capture all three venue configurations through amber phases and high speed, night headlights/brakes, a physical pre-green foul followed by a completed pass and zero reward, desktop/portrait, Low quality, all shifting families, low-power Mika and upgraded/nitrous Hammer launches, eighth/quarter-mile fixtures, timing boards and results. Rendering is checked for physics mutation; smoke remains capped at 8/24/48 particles per car. Control-bound/overlap and safe-area checks remain in the full UI suite.

The new ambience-only sample test peaks near 0.088 PCM with a largest adjacent-sample change near 0.0233, below its explicit mix/continuity limits. Live engine-plus-atmosphere checks at 30/60/120/144 render caps require zero steady-state underruns, unchanged engine-state targets and zero safety clamps. Startup/prior underruns are reported separately. A frame cap is not a measured phone frame rate.

The supplied gameplay contact sheet and shift measurements were reviewed again: restrained static bodies, wheel-light motion, a clear tree, unobstructed driving controls and separate slip reaction/ET informed the presentation. Paddle preference is preserved instead of reproducing the reference's H-pattern UI. The frozen estimated reference physics fixture remains unchanged; this pass does not claim identical timbre, proprietary formulas or exact reference beam dimensions.

## Limits

Physical Android/iOS ergonomics, low-end GPU/thermal/battery performance, output-device latency and subjective sound/lighting quality still need human device testing. Artwork is original stylized 2D rather than photorealistic licensed vehicles. Smoke is a bounded effect, not a fluid simulation; the drivetrain still uses one equivalent driven axle. Burnouts do not add a fabricated tire-warming bonus. Assisted staging intentionally remains an arcade convenience; manual staging supplies physical release/foul behavior without replacing the previous racing feel.
