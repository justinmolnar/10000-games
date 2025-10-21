# Contributing Guidelines (AI + Humans)

This checklist encodes our project’s architectural and refactoring rules. Follow it for every change. If something isn’t covered here, prefer prior patterns and DI-driven designs.

## Architectural rules

- Dependency Injection
  - Inject only specific dependencies via a `di` table in constructors/init (stateMachine, windowManager, settingsManager, programRegistry, models, Strings, Config).
  - No global reads of managers; no god objects. Views may receive DI but remain presentational.
- MVC / State Pattern
  - Models: data + rules only; no love.* calls; no rendering.
  - Views: draw-only; emit intent events; never mutate models or persist.
  - States/Controllers: own logic; validate, mutate models, persist, coordinate views.
- Requires + Data placement
  - Requires at top-level of files (except truly dynamic loads).
  - Externalize data (programs, strings, schemas, levels) to assets/data/*.json.
  - Centralize magic numbers to `config.lua` (or `di.config`), use `Constants` for enums, `Paths` for paths, `Strings.get` for UI text.
- Error handling & IO
  - Wrap file IO/JSON/dynamic loads in `pcall`. Handle nils safely and recover when possible.
  - Never overwrite user settings unless the value is truly unset; persist recoveries explicitly.
- Input + Update flow
  - Focused state/window handles input first; return handled flags. Global shortcuts only if unhandled.
  - Views return small semantic events; states use dispatch maps, not if/elseif ladders.
- Windowing + UI patterns
  - Respect `window_defaults` (min_w/min_h/resizable). Call `setViewport` after maximize/restore.
  - Context menus: options built by the owning state; separators are visual-only; actions routed centrally.
- Desktop + File Explorer
  - Icons managed via `DesktopIconController`; positions validated via `DesktopIcons`.
  - File Explorer: view emits intents; state handles navigation, opening, and context actions; special folders via FileSystem.
- Persistence
  - SettingsManager for user prefs; SaveManager for game data. ProgramRegistry may manage dynamic program entries in a separate save file.
  - Version save files; tolerate missing/invalid content gracefully.
- Performance patterns
  - Use object pooling for churn (e.g., bullets). Cache images/sprites; prewarm as needed.
  - Keep preview and final rendering math unified and in one place.
- Naming, constants, clarity
  - Replace magic numbers with named constants or config values. Prefer small helpers over long functions.
  - Prefer table-based dispatch to long if/elseif chains.
- Strings + UX
  - Use `Strings.get('path.key','fallback')` for all UI text.
  - Clear info/error messages, but logic remains outside views.
- Testing + stability
  - After edits: static checks, quick smoke test if applicable. Prefer adding tiny tests/checklists for changed behavior.

## Practical pre-merge checklist

- [ ] Deps injected via DI; no global reads.
- [ ] Views are presentational; state owns logic; models have no love.* calls.
- [ ] Strings/Paths/Constants used; no hardcoded UI text/paths/IDs.
- [ ] Magic numbers moved to config with safe fallbacks.
- [ ] IO/JSON guarded by pcall with graceful recovery.
- [ ] Window min sizes enforced; setViewport called after geometry changes.
- [ ] Context menu actions built/handled in the right state; dispatch tables used.
- [ ] Persistence updated as needed (save versioning, tolerant reads); no accidental overwrites.
- [ ] Performance-sensitive loops avoid churn; caches/pools used where relevant.
- [ ] Static checks pass; quick manual smoke matches expected behavior.

