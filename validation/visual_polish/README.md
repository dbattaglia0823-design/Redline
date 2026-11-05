# REDLINE visual polish review

Godot 4.6.3 rendered these captures from the running game. The phone captures use resized desktop windows at iPhone viewport dimensions.

| Screen | Desktop 1920 × 1080 | Portrait 390 × 844 | Landscape 844 × 390 |
| --- | --- | --- | --- |
| Garage | [Desktop](garage_1920x1080.png) | [Portrait](garage_390x844.png) | [Landscape](garage_844x390.png) |
| Upgrades | [Desktop](upgrades_1920x1080.png) | [Portrait](upgrades_390x844.png) | [Landscape](upgrades_844x390.png) |
| Upgrade detail | [Desktop](upgrade_detail_1920x1080.png) | [Portrait](upgrade_detail_390x844.png) | [Landscape](upgrade_detail_844x390.png) |
| Dealership | [Desktop](dealership_1920x1080.png) | [Portrait](dealership_390x844.png) | [Landscape](dealership_844x390.png) |
| Customization | [Desktop](customization_1920x1080.png) | [Portrait](customization_390x844.png) | [Landscape](customization_844x390.png) |
| Career | [Desktop](career_1920x1080.png) | [Portrait](career_390x844.png) | [Landscape](career_844x390.png) |
| Staging | [Desktop](staging_1920x1080.png) | [Portrait](staging_390x844.png) | [Landscape](staging_844x390.png) |
| Launch | [Desktop](launch_1920x1080.png) | [Portrait](launch_390x844.png) | [Landscape](launch_844x390.png) |
| Racing | [Desktop](racing_1920x1080.png) | [Portrait](racing_390x844.png) | [Landscape](racing_844x390.png) |
| Finish | [Desktop](finish_1920x1080.png) | [Portrait](finish_390x844.png) | [Landscape](finish_844x390.png) |
| Results | [Desktop](results_1920x1080.png) | [Portrait](results_390x844.png) | [Landscape](results_844x390.png) |

[All 30 cars through the shared vehicle preview renderer](roster_1920x1080.png)

The first capture pass exposed a floating stance in the portrait garage, clipping in the race status and results headers, and overlap between the finish notice and the trackside timing board. The final layouts lower the portrait showroom vehicle, give the timing fields more room, and place the finish board below the notice.

The desktop menus retain the game's centered canvas at widescreen resolutions. Physical-device performance, display safe areas, and touch feel still need iPhone testing.

To regenerate the captures, run `tests/capture_visual_polish.gd` from the project with Godot's graphical renderer and an isolated user-data directory. The capture drives real races and saves fixture progress while exercising the results flow.
