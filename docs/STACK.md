# Stack

Record of the toolchain this repository was brought up on: what is installed, which commands were used, and the problems that showed up. It is updated at the end of each phase. Versions live here on purpose; the README stays the map of the system and does not track them.

This demo does not claim compliance with IEC 61508, ISO 13849, or any other safety standard.

## Phase 0 — toolchain and agent setup

### What is installed

| Piece | Version | Role |
| --- | --- | --- |
| elan | 4.2.4 (227caca13, 2026-08-25) | Lean toolchain installer and version switcher |
| Lean | 4.34.1, `arm64-apple-darwin24.6.0`, commit `5045d0056413266e57c625dcd7c365b10e377c52`, Release | Kernel that checks definitions. No Mathlib. |
| Lake | 5.0.0-src+5045d00 | Package manager and build tool, shipped with that Lean |
| uv / uvx | already present at `/opt/homebrew/bin/uvx` | Runs the language-server MCP without a project-local Python env |
| lean-lsp-mcp | 0.31.0, pinned in `.cursor/mcp.json` | Agent access to goals, diagnostics, and hover via Lean's language server |
| ripgrep | 15.2.0 at `/opt/homebrew/bin/rg` | Recommended by lean-lsp-mcp for local search and source scans |

`lean-toolchain` contains `leanprover/lean4:v4.34.1`. That is the release elan installed when asked for `stable` on 2026-10-10. The file names the version, not the moving channel `stable`, so a later move of the channel does not change this repo.

The Lake package is `LeanSafetyGate`, created with `lake init LeanSafetyGate lib`. The `lib` template is a library only. It does not depend on Mathlib. `lake-manifest.json` records an empty dependency list and should stay committed so that fact is explicit.

`lake build` completed successfully after init (library root and the template's `LeanSafetyGate.Basic` module).

### Commands

```sh
curl -fsSL https://elan.lean-lang.org/elan-init.sh -o /tmp/elan-init.sh
sh /tmp/elan-init.sh -y --default-toolchain stable
export PATH="$HOME/.elan/bin:$PATH"
lake init LeanSafetyGate lib
lake build
uvx lean-lsp-mcp --version
brew install ripgrep
```

New shells pick up Lean because the installer appended `export PATH="$HOME/.elan/bin:$PATH"` to both `~/.zprofile` and `~/.profile`.

### Project-scoped language server

Cursor reads project MCP servers from `.cursor/mcp.json`. lean-lsp-mcp's README shows the same server as a global `uvx` entry; this repo pins it in the project file so a clone documents which server the agent is supposed to use.

The config differs from the README's snippet in three ways:

- `command` is `/opt/homebrew/bin/uvx`, not bare `uvx`. Cursor starts MCP processes without the login shell's `PATH`, and Homebrew is not on that default path.
- `args` pins `lean-lsp-mcp==0.31.0`. Unpinned `uvx lean-lsp-mcp` tracks PyPI latest.
- `env.PATH` starts with `~/.elan/bin` and `/opt/homebrew/bin`. The server runs `lake serve`, which has to find `lake` and `lean`. Putting Homebrew before other entries also selects Homebrew's `rg` (see below). `LEAN_PROJECT_PATH` is the absolute path of this checkout. stdio mode can infer a project from the working directory, but an explicit root avoids attaching the server to the wrong tree. A clone on another machine has to change that path.

### Problems

**Lean was not installed.** `elan`, `lean`, and `lake` were absent. The elan installer above fixed that. It did modify the two shell startup files named above.

**`could not canonicalize path: ~/.elan/toolchains` during install.** elan printed that warning several times before the toolchain directory existed. The download of `lean-4.34.1-darwin_aarch64.tar.zst` still finished, and `lean --version` reports 4.34.1. No further action.

**`failed to query latest release, using existing version`.** `lake init` and `lake --help` printed this while resolving which Lean to advertise. The already-installed toolchain was used. `lean-toolchain` was written as `leanprover/lean4:v4.34.1`, and `elan show` in this directory reports that file as the override. The pin does not depend on the release lookup succeeding.

**`rg` was easy to think was installed when it was not.** In this agent shell, `command -v rg` finds Cursor's bundled binary under `Cursor.app/.../ripgrep/bin`, which appears earlier in `PATH` than Homebrew. A language server started outside that shell would not see it. lean-lsp-mcp recommends `rg` for `lean_local_search` and for the source scan in `lean_verify`. `brew install ripgrep` installed 15.2.0. Homebrew itself warns that the Cursor bundle shadows `rg` in shells that put the bundle first. The MCP `PATH` lists `/opt/homebrew/bin` and does not list the Cursor bundle, so the server gets Homebrew's `rg`.

**The library template added a GitHub Actions workflow.** `.github/workflows/lean_action_ci.yml` runs `leanprover/lean-action@v1`, which builds the project. That is the template's build check only. The Phase 3 gate (no new `sorry` or axioms, spec lock, theorem manifest) is not this file and is not done.

**Phase 0 does not prove anything.** `LeanSafetyGate/Basic.lean` is still the template's `hello` definition. The controller model is Phase 1.

### Language-server check

A direct MCP client (the `mcp` Python client, speaking to `uvx lean-lsp-mcp==0.31.0` with this repo as `LEAN_PROJECT_PATH`) got both of the following back from Lean 4.34.1. The file was a throwaway `theorem probe : 1 + 1 = 2 := by rfl` plus `#check probe`, deleted afterward so it is not part of the library.

- `lean_goal` on the `rfl` line: before the tactic the goal was `⊢ 1 + 1 = 2`; after it there were no goals.
- `lean_diagnostic_messages`: one info diagnostic, `probe : 1 + 1 = 2`, from `#check`.

The first hand-rolled client never returned. It spoke Content-Length frames and left the server's stderr in an unread pipe, so the process blocked once that pipe filled. The official client drains both streams and completed in a few seconds. Use that, or any client that reads stderr, rather than a one-shot frame script.

This Cursor session's tool list did not include `lean-lsp` after `.cursor/mcp.json` was written. The server process works; the editor had not loaded the project server into the conversation yet.

That cleared when the project server was enabled in Cursor's MCP settings. The same session then called `lean_goal` and `lean_diagnostic_messages` on a throwaway file and got the same two results as the direct client: goal `⊢ 1 + 1 = 2` before `rfl`, no goals after it, and the `#check` info `probe : 1 + 1 = 2`.

A Lean 4 language-server extension was also installed in Cursor. That extension is the in-editor server. `lean-lsp-mcp` is a separate process the agent calls, and it starts its own `lake serve`. If the editor and the agent ever disagree about a diagnostic, that split is the first place to look.

## Phase 1 — requirements and specification

No toolchain change. `lake build` succeeds on `LeanSafetyGate.Model` and `LeanSafetyGate.Spec`. Diagnostics from `lean-lsp-mcp` on both files were empty. There are no theorems and no `sorry`.

`#guard` lines in `Model.lean` evaluate a few traces. They are not proofs of the propositions in `Spec.lean`.

**`List.get?` is not a field in Lean 4.34.** Writing `trace.get? i` failed with `Invalid field get?: The environment does not contain List.get?`. The indexing notation `trace[i]?` elaborates and is what `Spec.lean` uses.
