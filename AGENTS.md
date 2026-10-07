# Repository instructions

## Start here

- At the start of a task, read [docs/CODEBASE_MAP.md](docs/CODEBASE_MAP.md) for entry points, ownership and validation routes. Follow the task-specific document links before editing that area.
- When applying this template to a game or updating a derived game, follow [docs/template/APPLYING.md](docs/template/APPLYING.md).

## Boundaries

- Put game scenes, rules, assets, save schemas and game documents under `game/` and `docs/` respectively. `docs/template/` records template history and procedures.
- Use SaveManager for progress, Settings for preferences, InputManager for rebinding (register game actions with `register_action`), WindowManager for display changes, AudioManager for sound and SceneManager for scene transitions.
- Reuse `PauseMenu` (`ui/menus/`), `App.dialogs` (`ui/dialogs/`) and `SettingsPanel` (`ui/settings/`) before writing new pause, quit or settings UI.
- App owns the StoreService instance. Game code accesses `App.store`; SDK calls belong inside a StoreAdapter.
- Register save migrations and a verified native adapter through the `app/init_script` RefCounted hook. Read `docs/ARCHITECTURE.md` before changing initialization, persistence, service contracts or lifecycle.
- Change `core/` and `services/` only for shared framework requirements. Extend existing managers instead of adding duplicate singletons.

## Dependencies and validation

- Godot is locked to **4.7.2 Standard**, matching the mobile template. Use the matching export templates. Version changes are explicit coordinated work.
- For a new plugin/library, update the README BOM and `docs/DEPENDENCIES.md` with exact version, source, license, native SDKs, architecture and compatibility evidence.
- Keep unverified SDKs deferred behind the adapter contract. Mock success is allowed only in Debug, including directly instantiated mocks.
- Read `docs/STEAM.md` before SDK/Cloud integration and `docs/DISTRIBUTION.md` before export, signing, packaging or upload changes.
- Run affected checks using the commands in `docs/CODEBASE_MAP.md`. Inspect the summary and logs; Godot can exit 0 after script parse errors.
- Record actual template verification and limits in `docs/template/VALIDATION.md`; derived games record their own results. macOS Editor tests do not establish Windows binary or store-server support.
- Keep signing material, credentials and account tokens outside Git. Local identifiers and `steam_appid.txt` are excluded from export.

## Code and documentation

- Use GDScript, explicit APIs and typed public boundaries. Add a short Korean `##` class description to `.gd` files and Korean doc comments for major methods.
- Preserve failed save/settings/binding files until a user-directed recovery. Handle error returns and signals in game UI.
- Keep pause reasons independent and use `PROCESS_MODE_ALWAYS` for controls that must work during pause.
- When changing the template version, update `GameConfig.TEMPLATE_VERSION`, README and `docs/template/CHANGELOG.md` together.
- Update `docs/CODEBASE_MAP.md` when moving files or changing entry flows, public APIs, configuration propagation or validation commands.
- Human-facing docs (README, `docs/*.md`, `game/README.md`) are guides: write steps and facts for developers, keep agent-only rules in this file, and keep each contract in one document that others link to.
- `CLAUDE.md` imports this file; maintain instructions here.
