# market-garden-arena

A Roblox movement shooter: Source-style air strafing, bhop, surf, rocket jumping, ragdoll deaths. Written in Luau and synced into Studio with Rojo.

## How we work

- The developer directs and Claude implements. The developer is an experienced engineer who knows the engine and its server/client security model well, owns intent and design, and rarely edits code directly.
- Keep the developer in every decision. Plan before writing, keep diffs small and focused, and flag tradeoffs and non-obvious engine behavior. Ask before changing architecture or game feel.
- Commits: one per logical change, with a one-line title and a scope prefix for a series of related changes (`rocket-jump: initial implementation without VFX`). No attribution lines.
- **Movement feel is the developer's call.** Change tuning values in `GlobalConfig` only when asked, and say what each change should feel like so it can be playtested.
- Do not refactor or reformat code outside the task.

## Project notes (`brain/`, gitignored)

- `brain/docs/` is ground truth (design doc, specs, decisions). `brain/plans/` holds in-progress feature plans. `brain/journals/` holds dated session logs. Rules are in `brain/README.md`.
- Read the relevant files before planning a feature. Write a journal entry at the end of a meaningful session.

## Toolchain

Tools are pinned in `rokit.toml`. After cloning, run `rokit install`.

- `lune run check` formats (check only), lints, and type-checks `src/`. Add `--fix` to apply formatting, or pass file paths to limit it to those files.
- A PostToolUse hook (`.claude/settings.json`, `.lune/hook-check.luau`) runs the check on every `.luau` file Claude edits. Fix any diagnostics it reports before moving on.
- Type checking runs in strict mode (`.luaurc`) against the Roblox type definitions for the pinned luau-lsp version. A type error on an API usually means the API doesn't exist or is used wrong. Check the docs; never silence it with `any`.

## Rojo layout (`default.project.json`)

| Path | Studio location |
|---|---|
| `src/shared` | `ReplicatedStorage.Shared` |
| `src/server` | `ServerScriptService.Server` |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` |

- Files are the source of truth for code. Never edit synced scripts through the Studio MCP; Rojo will overwrite those edits or drift from them.
- `Workspace` and `ReplicatedStorage.Shared` set `$ignoreUnknownInstances`, so maps, models and assets built in Studio live only in the place file. The Studio MCP may inspect them.
- File suffixes: `.server.luau` is a Script, `.client.luau` is a LocalScript, and a plain `.luau` file is a ModuleScript.

## Architecture

- **Single-script architecture.** `src/server/main.server.luau` and `src/client/main.client.luau` are the only scripts. They require modules and call `:Init()`.
  - Server modules are `Services` (`src/server/Services`).
  - Client modules are `Controllers` (`src/client/Controllers`).
- **Module shape:** a table with `:` methods, such as `Init` and `OnCharacterAdded`, plus `Cleanup` on death or respawn. File-level locals hold the state. Follow this pattern for new modules, and register them in the matching `main` script.
- **Tuning values** live in `src/shared/GlobalConfig.luau`. Do not hard-code tuning numbers in controllers.
- **Movement** runs on the client, using `ControllerManager`, `AirController` and `GroundController`, with no legacy Humanoid physics:
  - `PhysicsController` owns input and the per-step update.
  - Strafing math is delegated to `StrafeController`, and surf detection to `SurfController`.
  - `PhysicsSetupService` sets up the character's controllers on the server.
- Keep pure math, such as slope tests, acceleration and velocity clipping, free of Roblox instances, so it can be unit-tested with Lune outside Studio.

## Luau and Roblox rules

- Use `task.wait`, `task.spawn` and `task.delay`, never `wait`, `spawn` or `delay`.
- Don't use deprecated body movers (`BodyVelocity`, `BodyGyro`, `BodyPosition`). Use constraints or `ControllerManager`. Use `Animator:LoadAnimation`, not `Humanoid:LoadAnimation`.
- The server never trusts the client. Validate every `OnServerEvent` argument: type, range, rate, and whether the player is alive or the tool is equipped. Remember that `FireClient` takes the player as its first argument.
- The client owns its character's physics (network ownership), so server-side forces on characters need care.
- Disconnect connections in `Cleanup`, and handle `CharacterAdded` and respawns.
- `Players.LocalPlayer` exists only on the client.

## Roblox docs

- A local clone of the docs (Roblox/creator-docs, English only) lives at `../roblox-creator-docs/content/en-us/`. Grep it first. The engine reference is in `reference/engine/{classes,enums,datatypes,globals,libraries}/*.yaml`, one file per API. Update it with `git -C ../roblox-creator-docs pull`.
- For conceptual questions, use semantic search: `https://create.roblox.com/docs/api/search?q=<url-encoded question>`
- Engine API index: https://create.roblox.com/docs/reference/engine/llms.txt
- Add `.md` to any docs URL for clean Markdown, e.g. https://create.roblox.com/docs/reference/engine/classes/ControllerManager.md
- Deprecated APIs: https://create.roblox.com/docs/reference/engine/deprecated.md
- Look up an API before using it when unsure, especially the newer physics controllers.

## Studio MCP

Use the built-in Studio MCP to inspect, test and debug: playtests, console output, the instance tree, and Studio-only content. Edit code through files.
