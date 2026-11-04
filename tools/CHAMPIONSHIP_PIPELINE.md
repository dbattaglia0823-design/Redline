# Championship authoring and validation

Championships consumes assets/data/championships.json. Stable event IDs are saved progression keys: retain them or add an explicit migration when changing the catalog.

1. Run tests/benchmark_roster.gd after changing physics/specifications or the class benchmark version.
2. Run tests/build_championships.gd to evaluate candidate configurations and generate fixed E-S builds and open events. These are real engine/gearbox/tire configurations, not horsepower or speed multipliers.
3. Run test_championships, test_career_economy_sim, test_career_save_migration and test_championships_ui through the standard validation tools.
4. Review the rendered screenshots and numeric balance reports. Keep opponent builds fixed when players upgrade their own cars.

Rewards and first-clear bonuses are defined centrally in Championships. Driver styles are actual inputs consumed by RaceAI. Saved entry contracts bind reward data before a race, and DriverProfile.award_race handles both original street progress and new championship/event records.

Class eligibility uses PerformanceClasses, whose signature includes mechanical configuration and tuning. Player race results and cosmetic appearance are not classification inputs. Installed nitrous capacity is exercised by the competent benchmark; stock vehicles without an installed kit cannot activate the legacy base bottle in new career events.
