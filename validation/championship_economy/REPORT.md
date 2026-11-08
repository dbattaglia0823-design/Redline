# Championship difficulty and betting economy

The 60 existing championship IDs, rival identities, ten rounds per class,
boss flags, mixed eighth/quarter-mile distances, open half-mile mode, motor-only
rules, player engine classes, and saved progress are retained. Rival vehicles
now have engines belonging to their championship class. The following results
use REDLINE's shared physics and actual AI controls, not acceleration bonuses.

## Opening matches and bosses

Each opener uses a stock opponent calibrated about 0.4 seconds behind the
slowest stock car in its class at a 0.18-second driver reaction. The regression
also tests all 30 stock cars with a 0.25-second reaction, correct launches and
shifts; every one beats its own opener by more than 0.1 seconds. Faster stock
cars naturally have more margin. Poor launches, missed shifts and red lights
can still lose an opening race.

After the opener, real engine, induction, traction, transmission and nitrous
builds become progressively faster. All 54 follow-up matches are also at least
0.08 seconds faster than their previous contracts over the normalized quarter,
and at least 0.03 seconds faster over each event's actual race distance.
All 30 stock cars lose to their class boss
by more than 0.7 seconds in the competent-driver simulation. Bosses remain
beatable with purchased upgrades and good control; the full funded career is
tested through the actual purchase, equipping, wagering and award APIs.

Times below are quarter-mile-normalized green-to-finish seconds, including
AI reaction. Eighth-mile events retain their actual race distance. The old
times were remeasured using the same physics before changing the contracts.

| Class | Slowest stock | New opener | Old boss | New boss | Opening bet cap | Boss bet cap |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| E | 16.242 | 16.642 | 15.188 | 11.044 | $2,000 | $50,000 |
| D | 15.145 | 15.545 | 14.436 | 10.296 | $4,000 | $100,000 |
| C | 13.996 | 14.396 | 13.172 | 9.515 | $7,500 | $187,500 |
| B | 13.175 | 13.575 | 12.375 | 8.961 | $13,000 | $325,000 |
| A | 12.351 | 12.751 | 10.843 | 8.121 | $22,000 | $550,000 |
| S | 10.645 | 11.045 | 7.789 | 6.945 | $40,000 | $1,000,000 |

## Betting is the only race income

- No purse, loss/finish payment, first-win cash, boss cash, or automatic bailout.
- A winning bet returns twice the stake: the stake back plus equal net profit.
  Losing, red-lighting or abandoning a race loses the stake. Duplicate results
  cannot pay again. Entry binds the authoritative event and checks its cap.
- Old bound contracts containing obsolete purses or bonuses cannot restore
  those payments. Existing balances, purchased parts, ownership and progress
  are preserved; a price increase does not charge an owned part again.
- Free races remain available at zero credits and still earn XP and advance
  eligible championship wins. They award zero cash. Spending or losing all
  cash intentionally removes the ability to earn race money until the player
  has a bankroll; this risk was explicitly selected by the user.
- Trophies and next-class unlocks are independent of cash rewards. First-clear
  trophy presentation and replay guards remain even though cash bonuses are zero.
- Caps rise by class and round, including motor-only heats (their nitrous
  restriction remains). Open rivals have caps ordered by measured quarter-mile
  pace. Wager buttons/slider steps adapt to the available maximum, and an exact
  cap remains selectable. The balance always limits the stake.

## Upgrade pricing

Stage prices are incremental, and skipping ahead sums all unowned stages.
The multipliers are base × 1 / 3 / 8; gearbox stages extend to ×18 / ×36.
For example, engine tiers cost $700 / $2,100 / $5,600; buying tier three from
stock costs $8,400. Gearbox stages cost $900 / $2,700 / $7,200 / $16,200 /
$32,400, totaling $59,400 from stock. Existing owned lower/higher tiers can be
equipped again without another charge.

Component ladders also have larger price gaps. All prices below are full
component purchase prices; owned parts are free to re-equip in their fitment.

| Component | Previous | New |
| --- | ---: | ---: |
| Hardened internals | $3,600 | $5,500 |
| Low-friction bearings | $2,100 | $4,000 |
| Thermal protection | $2,800 | $4,500 |
| Shift calibration | $3,200 | $6,500 |
| Billet gearset and case | $8,200 | $24,000 |
| Pressure upgrade | $3,400 | $6,500 |
| Response calibration | $2,600 | $5,000 |
| High-flow charge piping | $2,300 | $4,000 |
| Charge cooling | $3,000 | $6,000 |
| Billet race assembly | $6,600 | $12,000 |
| 8% stroker kit | $4,200 | $9,000 |
| High-compression pistons | $2,500 | $6,000 |
| High-flow intake plenum | $1,550 | $2,250 |
| Velocity stack intake | $2,900 | $6,750 |
| Race intake manifold | $4,800 | $18,000 |
| Performance pump and injectors | $3,100 | $5,100 |
| Ethanol-ready race fuel kit | $5,100 | $15,300 |
| Programmable ECU | $2,300 | $2,850 |
| Track ECU | $3,800 | $8,550 |
| Motorsport ECU | $5,700 | $22,000 |
| Large-frame turbo | $7,000 | $12,000 |
| Roots supercharger | $6,300 | $9,000 |
| Centrifugal supercharger | $7,200 | $11,000 |
| Electronic boost controller | $1,700 | $3,200 |
| Twin-plate clutch pack | $2,750 | $4,350 |
| Race clutch / internal packs | $4,600 | $11,600 |
| Carbon triple-disc clutch | $7,800 | $29,000 |
| Straight-line locked differential | $3,000 | $6,500 |
| Tall drag wheel set | $3,300 | $4,800 |
| Ultra-high-performance tires | $1,750 | $2,300 |
| Street drag radials | $2,800 | $6,200 |
| Competition drag radials | $4,450 | $15,000 |
| Full drag slicks | $6,300 | $32,000 |
| Pro drag radials | $7,900 | $55,000 |
| Pro soft-compound slicks | $9,900 | $90,000 |
| Adjustable coilovers | $2,600 | $4,700 |
| Performance drag suspension | $3,700 | $12,000 |
| Competition drag shocks and springs | $5,350 | $26,000 |
| Professional drag racing suspension | $7,400 | $50,000 |
| Pro four-way drag suspension | $10,500 | $90,000 |
| Tuned exhaust manifold | $2,100 | $4,200 |

## Betting-funded progression simulation

The automated route completed **all 60 championship races**, starting with the
normal $2,400 balance and stock Miata. It used **96 extra
betting replays**, conservative stakes of at most one-third of its current
balance, exact staged prices, actual purchase/equip APIs, retained per-car
ownership, and zero non-betting race income. It kept $1,000 for betting after
planned purchases. This is one attainable route, not an optimal buying plan,
a human win-rate claim, or a guarantee against bankruptcy. A player willing
to stake more risks more; free races never substitute for betting income.
The per-race car, upgrade cost, player/rival times, balance and replay count
are recorded in `betting_career.json`.

## All 60 matches

| Race | Rival car | Old quarter | New quarter | Actual-distance time, old → new | Bet cap |
| --- | --- | ---: | ---: | ---: | ---: |
| class_E_0 | miata | 18.678 | 16.642 | 18.678 → 16.642 | $2,000 |
| class_E_1 | miata | 17.867 | 15.745 | 11.902 → 10.373 | $3,000 |
| class_E_2 | miata | 17.080 | 15.019 | 17.080 → 15.019 | $4,400 |
| class_E_3 | civic_si | 16.922 | 14.401 | 11.163 → 9.492 | $6,400 |
| class_E_4 | miata | 16.219 | 13.786 | 16.219 → 13.786 | $9,200 |
| class_E_5 | miata | 16.077 | 13.170 | 16.077 → 13.170 | $13,000 |
| class_E_6 | miata | 16.028 | 12.610 | 10.524 → 8.514 | $18,000 |
| class_E_7 | civic_si | 15.697 | 12.108 | 15.697 → 12.108 | $25,000 |
| class_E_8 | civic_si | 15.483 | 11.605 | 10.097 → 7.903 | $34,000 |
| class_E_9 | civic_si | 15.188 | 11.044 | 15.188 → 11.044 | $50,000 |
| class_D_0 | gti_vr6 | 16.562 | 15.545 | 16.562 → 15.545 | $4,000 |
| class_D_1 | gti | 16.333 | 14.706 | 10.865 → 9.625 | $6,000 |
| class_D_2 | gti | 15.730 | 14.022 | 15.730 → 14.022 | $8,800 |
| class_D_3 | integra | 15.619 | 13.443 | 10.205 → 8.847 | $12,800 |
| class_D_4 | integra | 15.493 | 12.869 | 15.493 → 12.869 | $18,400 |
| class_D_5 | integra | 15.356 | 12.290 | 10.066 → 8.184 | $26,000 |
| class_D_6 | gti | 15.131 | 11.767 | 9.905 → 7.918 | $36,000 |
| class_D_7 | gti_vr6 | 15.025 | 11.294 | 15.025 → 11.294 | $50,000 |
| class_D_8 | gti | 14.675 | 10.824 | 9.592 → 7.259 | $68,000 |
| class_D_9 | rsx | 14.436 | 10.296 | 14.436 → 10.296 | $100,000 |
| class_C_0 | s2000 | 15.691 | 14.396 | 15.691 → 14.396 | $7,500 |
| class_C_1 | type_r | 15.270 | 13.613 | 10.094 → 9.106 | $11,300 |
| class_C_2 | type_r | 14.612 | 12.981 | 14.612 → 12.981 | $16,500 |
| class_C_3 | evo | 14.562 | 12.442 | 9.526 → 8.125 | $24,000 |
| class_C_4 | z350 | 14.509 | 11.907 | 14.509 → 11.907 | $34,500 |
| class_C_5 | s2000 | 14.179 | 11.370 | 9.292 → 7.508 | $48,800 |
| class_C_6 | type_r | 14.004 | 10.883 | 9.198 → 7.170 | $67,500 |
| class_C_7 | s2000 | 13.604 | 10.442 | 13.604 → 10.442 | $93,800 |
| class_C_8 | type_r | 13.536 | 10.006 | 8.895 → 6.590 | $127,500 |
| class_C_9 | evo | 13.172 | 9.515 | 13.172 → 9.515 | $187,500 |
| class_B_0 | supra | 14.823 | 13.575 | 14.823 → 13.575 | $13,000 |
| class_B_1 | supra | 14.332 | 12.834 | 9.433 → 8.507 | $19,500 |
| class_B_2 | supra | 13.878 | 12.233 | 13.878 → 12.233 | $28,600 |
| class_B_3 | golf_r | 13.807 | 11.728 | 9.039 → 7.635 | $41,600 |
| class_B_4 | m3 | 13.322 | 11.220 | 13.322 → 11.220 | $59,800 |
| class_B_5 | supra_gr | 13.306 | 10.707 | 8.783 → 7.039 | $84,500 |
| class_B_6 | supra | 12.866 | 10.251 | 8.349 → 6.779 | $117,000 |
| class_B_7 | golf_r | 12.665 | 9.834 | 12.665 → 9.834 | $162,500 |
| class_B_8 | supra_gr | 12.546 | 9.417 | 8.162 → 6.200 | $221,000 |
| class_B_9 | supra | 12.375 | 8.961 | 12.375 → 8.961 | $325,000 |
| class_A_0 | z400 | 13.267 | 12.751 | 13.267 → 12.751 | $22,000 |
| class_A_1 | camaro | 12.882 | 12.009 | 8.509 → 8.005 | $33,000 |
| class_A_2 | camaro | 12.265 | 11.409 | 12.265 → 11.409 | $48,400 |
| class_A_3 | redeye | 12.206 | 10.898 | 8.129 → 7.316 | $70,400 |
| class_A_4 | redeye | 12.153 | 10.387 | 12.153 → 10.387 | $101,200 |
| class_A_5 | r8 | 12.068 | 9.879 | 8.084 → 6.533 | $143,000 |
| class_A_6 | mustang | 11.991 | 9.415 | 7.746 → 6.222 | $198,000 |
| class_A_7 | gtr | 11.607 | 8.998 | 11.607 → 8.998 | $275,000 |
| class_A_8 | mustang | 11.464 | 8.583 | 7.718 → 5.661 | $374,000 |
| class_A_9 | r8 | 10.843 | 8.121 | 10.843 → 8.121 | $550,000 |
| class_S_0 | z06 | 11.859 | 11.045 | 11.859 → 11.045 | $40,000 |
| class_S_1 | z06 | 10.235 | 10.113 | 6.912 → 6.718 | $60,000 |
| class_S_2 | gt500 | 9.853 | 9.735 | 9.853 → 9.735 | $88,000 |
| class_S_3 | mclaren | 9.826 | 9.403 | 6.486 → 6.366 | $128,000 |
| class_S_4 | turbo_s | 9.445 | 8.952 | 9.445 → 8.952 | $184,000 |
| class_S_5 | chiron | 8.988 | 8.501 | 5.959 → 5.820 | $260,000 |
| class_S_6 | gt500 | 8.826 | 8.091 | 5.844 → 5.327 | $360,000 |
| class_S_7 | z06 | 8.583 | 7.725 | 8.583 → 7.725 | $500,000 |
| class_S_8 | turbo_s | 8.218 | 7.354 | 5.606 → 4.893 | $680,000 |
| class_S_9 | sf90 | 7.789 | 6.945 | 7.789 → 6.945 | $1,000,000 |

## Reproduce and validate

```
python tools/run_regressions.py --godot C:/Godot/godot.exe --output .qa/championship-economy/regressions
python tools/report_championship_economy.py
```

`test_betting_progression.gd` checks every stock opener, stock-versus-boss
performance, all 60 increasing caps, betting settlement, zero-credit XP/progress,
old-contract payouts, duplicate awards and staged ownership prices.
`test_championships.gd` checks increasing normalized and same-distance pace,
class-correct rival engines, six trophies, unlocks, rewards and saved progress.
`test_career_economy_sim.gd` exercises a complete betting-funded career.

The offline authoring script is `tests/rebalance_championships.gd`; `-- --write`
publishes its measured real builds. It is not run during play and does not
rubber-band opponents to the player's upgrades. `tests/build_championships.gd`
refreshes performance metadata without changing engine classes. Historical
physics-only measurements remain in `validation/physics_audit`.

## Validation results and existing shutdown issue

The final batch passed all 21 headless suites plus the Godot import. After
the last two Class S adjustments, the targeted difficulty test passed all
335 checks and the complete betting-funded 60-race economy simulation passed
again. Desktop/phone/landscape wager interactions, all-class race UI, upgrade
purchasing, controller inputs and trophy flow passed their visual assertions.
Million-credit stakes were tested through actual mouse/touch entry events.

The Windows Godot process exits with access violation `0xC0000005` after these
graphical tests finish, despite the assertions passing. This also reproduces
with a pre-change source overlay (verified by the old $2,100 tier-two engine
quote, versus the new $2,800 cumulative quote) in a minimal garage-open/close
probe. An empty renderer probe exits cleanly. The same shutdown fault occurs
with native OpenGL and ANGLE, so clean graphical-process shutdown is **not**
claimed. This existing application shutdown issue remains outside this
championship/economy update. Evidence and exit statuses are recorded in
`regressions.json`; local screenshots and raw logs are under
`.qa/championship-economy`. Physical phone/controller hardware was not tested.
