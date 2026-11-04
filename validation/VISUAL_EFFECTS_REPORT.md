# Static vehicle presentation and physical effects

The existing twelve static vehicle illustrations and three wheel finishes remain in use. Bodies, wheels, brake calipers, rotating highlights, smoke and exhaust are separate lightweight drawing layers. No 3D models, full-screen blur passes or copied reference assets were introduced.

Driven-wheel phase and angular speed read the simulation's wheel_angle and wheel_omega, including slip. Undriven wheels use distance/tire-radius phase and speed/tire-radius angular velocity. Engine RPM never drives wheel rotation. Wheel highlights advance by the physical angle; bounded arcs and a faint annulus approximate shutter blur as angular speed rises. Brake calipers and reflection arcs stay fixed. Low quality uses static spokes with physical moving highlights; Medium/High rotate the spoke layer as well.

Body pitch and launch compression now move the body sprite independently of the ground-contact wheel anchors. Small RPM-based idle vibration, existing bounded camera feedback, physics-driven exhaust pulses and distance-driven scenery supply movement around the static artwork. The opponent gets the same feedback layer. Smoke follows driven axle selection and installed tire dimensions, with lane-aware draw order so a burnout plume is visible instead of being hidden under the tire.

## Quality controls

Choose EFFECTS on the Driver screen or paused race menu. The preference persists in existing saves; older saves default to High.

| Preset | Wheel arc segments | Rotor holes | Smoke cap per car | City window detail | Camera intensity |
| --- | ---: | ---: | ---: | --- | ---: |
| Low | 16 | 0 | 8 | Off | 25% |
| Medium | 24 | 6 | 24 | Reduced | 65% |
| High | 36 | 12 | 48 | Full | 100% |

Quality changes prune particles immediately, including while paused. Particle lifetime is under 0.65 seconds and emission is capped per update. Rim styles and paints remain compatible. Authored wheelbase/wheel_y/wheel_radius anchors define stock illustration geometry; installed physical tire radius scales wheel visuals relative to the model's factory radius, bounded to 80–118% to avoid extreme art clipping. All currently offered wheel/tire packages fit within that range. Garage, appearance, owned-car and racing views use these dimensions; dealership factory previews retain factory sizes.

## Verification

The new motion tests verify neutral free revving without wheel animation, direct axle/rolling speed mapping, no invented phase jump on gear selection, actual low-grip stationary burnouts, braking to a stop, 30/60/120/144 FPS input consistency, all twelve models' tire sizes, pause freezing, quality budgets, and preference persistence. Graphical tests render high/low burnouts and braking, exercise the pause quality control, and check that drawing and quality changes leave drivetrain telemetry unchanged. Stage/parts purchases and customization are preserved.

The existing regression suite passed, including the coupled physics, audio, driving controls, garage/dealership, career and 204 transmission comparisons. Desktop screenshots were inspected. The Windows runtime audio tests retain their four rendering caps; those are cap settings, not measured phone FPS. Tests do not establish subjective similarity, speaker latency, or low-end Android/iOS performance.

The solver has one equivalent driven-wheel state, not independent four-wheel/ABS telemetry. AWD therefore shares that state across both drawn axles; free wheels assume rolling contact. Blur, suspension compression, smoke and vibration are documented presentation approximations and never change grip, mass, engine load or vehicle motion. The previously reported intermittent native Windows shutdown issue remains a monitoring item; this visual work does not claim to resolve it conclusively.
