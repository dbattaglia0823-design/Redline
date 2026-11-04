# Quarter-mile race distances and opponent camera positioning

- All 15 career contracts now specify 402.336 m (1/4 mile). Race entry also enforces that minimum and synchronizes the active contract. Longer future distances remain supported. Intermediate split timings and standalone benchmark measurements are unchanged.
- Removed both horizontal clamps from the rival's camera-relative position. Position is now the real distance gap times the existing pixels-per-metre scale on desktop and portrait layouts. Large leads or deficits put the rival completely off-screen; catching up brings it back naturally. Player camera position, vehicle physics, AI strength, rewards and saves are unchanged.
- Native desktop/portrait checks verify equal-position alignment, proportional small gaps, full departure at either edge and natural re-entry. Screenshots are in validation/race_camera/.
- The stock starter still wins the revised opening quarter-mile in the native keyboard test: 17.598 s versus 19.258 s, with correct rewards. All 15 rival simulations finish without safety clamps.
