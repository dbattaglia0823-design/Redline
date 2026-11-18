# REDLINE — development instructions

REDLINE is an **existing Godot 4.6 drag-racing game**. Do not rebuild working systems from reference screenshots or from toolkit examples.

## Selective context

1. Read `docs/INDEX.md`, then one task-specific document, followed by current code/tests.
2. Start with `docs/ARCHITECTURE.md` for responsibility boundaries; for drag simulation and vehicle behavior see `docs/systems/RACE_AND_VEHICLES.md`.
3. For toolkit UI wiring, read `tools/TOOLKIT_UI_INTEGRATION.md`, then actual GDScript controllers. Treat exported layouts as interface contracts, not finished gameplay.
4. Reusable practices and optional Codex skills live in [Game-Dev-Toolkit](https://github.com/dbattaglia0823-design/Game-Dev-Toolkit/tree/main/knowledge). Cross-repository links do not automatically grant Codex file access; access must be configured for the session.

## Preserve and verify

- Use `project.godot` and CI to determine engine requirements. Current CI executes Godot **4.6.3** with `tools/run_regressions.py`; the project runs physics at **120 Hz**.
- Preserve current profile/career saves, credits/betting, progression, vehicle IDs, upgrade hardware, shift controls, wheel visual layers and responsive mobile UI. Changes to saved data require migration tests.
- Distinguish what is **playable** from **preview-only**: bike and boat/jet-ski dealership tabs are currently illustrative, not purchasable vehicle support.
- Do not remove seemingly unused vehicle art, sound banks or test fixtures without checking references, import paths and pipeline documentation.
- Add focused regression tests with implementation changes. Run the real project's headless runner and graphical checks where relevant; explain what was not tested.
- Only after verifying code/tests, update `docs/` and `docs/HANDOFF.md` with the actual modified paths, test output, and remaining risks.
- Never copy external skills, vaults, assets or scripts without checking license, trust and Godot compatibility; never commit secrets or local machine paths.

## Locally installed skills

Use the specific skill under `.agents/skills/` only when relevant. See [docs/SHARED_SKILLS.md](docs/SHARED_SKILLS.md) for source/version and update instructions. These are optional snapshots; do not load all of them by default.
