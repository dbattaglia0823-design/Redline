# Career, tuning and competition validation

Implemented in the existing REDLINE project. The existing coupled drivetrain, static vehicle renderer, audio, garage, dealership, upgrade UI and save format remain in use.

## Phase 1-2 completion

The saved tuning/test-track implementation was inspected and revalidated after the interrupted session. Hardware-gated tuning, vehicle-specific named presets, bounded simulated optimization, practice races and interactive telemetry passed their model and rendered UI checks. Practice uses the ordinary race solver, staging beams and timing; it does not open a career wager or change money/XP/progression.

## Phase 3: class career and rivals

- Six championships, E through S, with five fixed authored rival builds each. The standard quarter-mile benchmark determines current class from parts, gearing and tuning. Actual player race times never change eligibility. Factory and current classes remain separate.
- Five open challenges include a no-stake recovery event, a specific Miata competition and a half-mile drag challenge. Class heats alternate quarter- and eighth-mile distances; the original street series stays quarter-mile.
- Thirty named class rivals have different reactions, launch strategies, throttle/traction decisions, shift errors and mistakes. Open drag rivals can operate transbrakes and nitrous. All use Drivetrain; there are no speed multipliers or rubber-banding.
- Benchmarked competitive potential includes spray from installed nitrous stages/controllers. New career events require an installed nitrous kit/controller to use spray, closing the mismatch with unmodified factory benchmarks. Legacy street/practice controls remain compatible.
- A completed preceding championship or an overall-win milestone unlocks higher series. Previous street wins count toward these unlocks. This avoids trapping a player who upgrades out of the starting class.
- First-clear final bonuses are claimed once. Race entry binds the canonical event and wager; settlement uses that stored contract, not mutable UI values. Duplicate finish callbacks cannot pay twice.
- The new career fields are additive: original street progress, currency, cars, tuning presets, upgrades and cosmetics are retained. An old save is backed up before championship migration. Interrupted wagers retain the previous forfeiture policy.

## Phase 4: UI integration

Class career is on the existing Race board; original street series remains accessible. Cards show progress and unlocks. Rival details show vehicle art, real HP, configuration, simulated matchup, distance, payout and wager risk. Race HUD and results identify the class event; completed bonuses are clearly marked as earned. Rival preview paint/wheels match race presentation. Existing day/night tracks are selected by event metadata.

Garage actions were consolidated: Upgrades and Customize use the existing dock, Test Track is the single secondary garage entry, and advanced tuning is reachable from upgrade details. Desktop, portrait, safe-area and control-layout tests cover the integrated flows. No new rendering theme or duplicate purchase system was created.

## Phase 5: evidence

- Every class rival was benchmarked and raced through the same AI/drivetrain. Each final is faster than its opening rival under equal quarter-mile conditions; differing heat distances are also simulated separately.
- Native keyboard gameplay: stock Miata first Class E win, approximately 17.790 s total against 18.700 s for Dex (ET 16.917 s, reaction 0.873 s). The first rival remains beatable with the starting car.
- Native end-to-end checks cover engine purchase, programmable ECU, launch tuning, saved preset, practice, telemetry, class racing, rewards, another car, and retained per-car tuning after save/load.
- The economy simulation evaluated actual part-stage and conversion costs, retained owned builds, and competent simulated controls with zero wagers. It completed all 30 heats with six extra recovery races. An optimized Camaro completed the final at approximately 8.757 s against 8.848 s for the rival; buying a supercar was not required. This is an attainable simulated route, not a human win-rate prediction.
- Detailed reports: championship_balance.json, championship_summary.json, career_economy_progression.json, tuning/model.json, individual test logs and suite_results.json. Screenshots: class_career/ and tuning/.

## Limits

Physical iPhone comfort, notch/orientation behavior and sustained low-end mobile performance require device playtesting. Rival identity and difficulty are implemented; their memorability and long-term economy enjoyment need human feedback. The optimizer is bounded, not a guaranteed global optimum. Tire-pressure/differential behavior uses documented straight-line aggregate approximations. Session practice comparisons are not a persistent run archive; saved tuning presets and new career event records persist.

The reference recordings inform observable behavior; they do not reveal proprietary formulas or exact hidden vehicle configurations. Existing fitted-reference replay checks are regression checks, not independent proof of original-game physics or an authentic engine-timbre match.
