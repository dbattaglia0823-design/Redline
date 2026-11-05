# Championship authoring and validation

Championships consumes assets/data/championships.json. Stable event IDs are saved progression keys: retain them or add an explicit migration when changing the catalog.

1. Run tests/benchmark_roster.gd after changing physics/specifications or the class benchmark version.
2. Edit the authored event rows in the championship catalog. Run tests/build_championships.gd to benchmark the builds and write a report under .qa. Pass --write after Godot's -- separator to update measured metadata in the catalog.
3. Run test_championships, test_career_economy_sim, test_career_save_migration and test_championships_ui through the standard validation tools.
4. Review the rendered screenshots and numeric balance reports. Keep opponent builds fixed when players upgrade their own cars.

The catalog defines purses, first-clear bonuses and the driving inputs consumed by RaceAI. Compare every rival at the quarter mile to check the ladder's difficulty independently of the event distance. The round-ten boss awards a trophy and opens the next class. Saved entry contracts bind rewards before the race.

Class eligibility uses PerformanceClasses, whose signature includes mechanical configuration and tuning. Player race results and cosmetic appearance are not classification inputs. Installed nitrous capacity is exercised by the competent benchmark; stock vehicles without an installed kit cannot activate the legacy base bottle in new career events.
