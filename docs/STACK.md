# Stack

Toolchain this repository is built on, and the problems worth remembering. Versions live here on purpose; the README stays the map of the system and does not track them.

This demo does not claim compliance with IEC 61508, ISO 13849, or any other safety standard.

## Phase 0 — toolchain and agent setup

### What is installed

| Piece | Version | Role |
| --- | --- | --- |
| elan | 4.2.4 (227caca13, 2026-08-25) | Lean toolchain installer and version switcher |
| Lean | 4.34.1, commit `5045d0056413266e57c625dcd7c365b10e377c52`, Release | Kernel that checks definitions. No Mathlib. |
| Lake | 5.0.0-src+5045d00 | Package manager and build tool, shipped with that Lean |
| uv / uvx | a recent uv that can run `uvx` | Runs the language-server MCP without a project-local Python env |
| lean-lsp-mcp | 0.31.0, pinned in `.cursor/mcp.json` | Agent access to goals, diagnostics, and hover via Lean's language server |
| ripgrep | any current `rg` on the server's `PATH` | Recommended by lean-lsp-mcp for local search and source scans |

`lean-toolchain` contains `leanprover/lean4:v4.34.1`. That is the release elan installed when asked for `stable` on 2026-10-10. The file names the version, not the moving channel `stable`, so a later move of the channel does not change this repo.

The Lake package is `LeanSafetyGate`, created with `lake init LeanSafetyGate lib`. The `lib` template is a library only. It does not depend on Mathlib. `lake-manifest.json` records an empty dependency list and should stay committed so that fact is explicit.

### Commands

```sh
curl -fsSL https://elan.lean-lang.org/elan-init.sh -o /tmp/elan-init.sh
sh /tmp/elan-init.sh -y --default-toolchain stable
export PATH="$HOME/.elan/bin:$PATH"
lake init LeanSafetyGate lib
lake build
uvx lean-lsp-mcp --version
```

The elan installer adds `~/.elan/bin` to the login shell's startup file. A non-login shell does not read that file, so `lake` is missing until `PATH` is set explicitly. `scripts/gate.sh` prepends `~/.elan/bin` when that directory exists. GitHub Actions does not need the prepend: `lean-action` puts elan on `PATH` for later steps.

### Project-scoped language server

Cursor reads project MCP servers from `.cursor/mcp.json`. lean-lsp-mcp's README shows the same server as a global `uvx` entry. This repo pins it in the project file so a clone documents which server the agent is supposed to use.

The committed config differs from that snippet in three ways:

- `command` is an absolute path to `uvx`. Cursor starts MCP processes without the login shell's `PATH`, so a bare `uvx` is often not found.
- `args` pins `lean-lsp-mcp==0.31.0`. Unpinned `uvx lean-lsp-mcp` tracks PyPI latest.
- `env.PATH` starts with `~/.elan/bin` and the directory that contains `uvx` and `rg`. The server runs `lake serve`, which has to find `lake` and `lean`. `LEAN_PROJECT_PATH` is an absolute path. stdio mode can infer a project from the working directory, but an explicit root avoids attaching the server to the wrong tree. A clone on another machine has to change both absolute paths.

Writing `.cursor/mcp.json` does not attach the server. It has to be enabled in Cursor's MCP settings before an agent session can call it.

The Lean extension in the editor and `lean-lsp-mcp` are separate processes. Each can start its own `lake serve`. If the editor and the agent disagree about a diagnostic, that split is the first place to look.

An editor-bundled `rg` can appear earlier on `PATH` than a normal install, so `command -v rg` succeeding does not mean the MCP server will see a useful `rg`. The server's own `PATH` has to list a real ripgrep. lean-lsp-mcp uses it for `lean_local_search` and for the source scan in `lean_verify`.

### Problems

**elan may warn `could not canonicalize path: ~/.elan/toolchains` during install.** That showed up before the toolchain directory existed. The download still finished and `lean --version` reported 4.34.1. No further action.

**`failed to query latest release, using existing version`.** `lake init` printed this while resolving which Lean to advertise, and used the toolchain already installed. `lean-toolchain` was still written as `leanprover/lean4:v4.34.1`. The pin does not depend on that lookup succeeding. `elan show` in the project directory reports the file as the override.

**A hand-rolled MCP client deadlocks if it does not read stderr.** Content-Length frames on stdin are not enough. Once the server fills an unread stderr pipe, it stops writing the response. Use a client that drains both streams. The official Python MCP client does.

**`lake init` adds a GitHub Actions workflow that only builds.** `.github/workflows/lean_action_ci.yml` comes from the library template and runs `leanprover/lean-action@v1`. Phase 3 added the specification gate as a later step in that same workflow. The action's build is not itself the sorry, axiom, or spec-lock check.

## Phase 1 — requirements and specification

No toolchain change. `#guard` lines in `Model.lean` evaluate a few traces. They are not proofs of the propositions in `Spec.lean`.

**`List.get?` is not a field in Lean 4.34.** Writing `trace.get? i` failed with `Invalid field get?: The environment does not contain List.get?`. The indexing notation `trace[i]?` elaborates, and that is what `Spec.lean` uses.

## Phase 2 — proofs

`LeanSafetyGate/Proofs.lean` proves all six propositions. There is no `sorry`. Each theorem depends only on `propext`.

The shape of every proof is the same. `step_motor_true_iff` says when one scan turns the motor on. The trace theorems induct on the input list and carry an arbitrary starting `State`, plus the fact that its latch equals the specification's latch. `Spec.motorAt` is the special case that starts from `init`. R4 is one application of the R2 theorem: a latched cycle is off whether or not start is pressed.

What took the time:

- The motor fact is a four-way split on the latch, the guards, start, and the previous motor bit, closed with `simp_all`. The goal before that last tactic is the `if` inside `step` after the latch rewrite. That was the Boolean core; the trace inductions are bookkeeping around it.
- A `have` whose type was an inline `match i with` was elaborated as a match on `i` together with nearby hypotheses. The induction hypothesis would not take that term. Naming the pattern `prevWasOff` fixed it. The compiler's type mismatch, which listed the extra match variables, was the diagnosis.
- `guardsOk = true` unfolded to a nested `∧` that was not definitionally the flat one in the specification. `and_assoc` closes it.
- `List.getElem?_cons_zero` is not a `@[simp]` lemma. Naming it in `simp` was redundant once the zero case reduced on its own, and the unused-argument warning said so.

R3 and R6 are the proofs that had to talk about the previous cycle. On the first cycle of a suffix, "previous" is the motor bit in the carried state; after that it is the previous output. Getting those two to be the same `Nat` recursion was the fiddly part. R1, R2, and R5 were the same induction with less memory.

## Phase 3 — CI gate

No new toolchain. `lean-action` builds the project on GitHub, then runs `scripts/gate.sh`. Locally that is `bash scripts/gate.sh`. The script builds again; on a warm `.lake` directory that is a no-op.

The script checks four things after the build:

- Lean sources contain no `sorry`, `admit`, or `axiom`. The pattern is a character class rather than `\b`, so BSD and GNU grep agree.
- `spec.lock` is the SHA-256 of `LeanSafetyGate/Spec.lean`. macOS has `shasum`; Ubuntu CI has `sha256sum`. The script uses whichever is present.
- Every `def <name> : Prop` in `Spec.lean` is listed in `spec.manifest`, and nothing else is. Propositions have to be written in that shape, at the start of a line, or the gate cannot see them.
- For each manifest name, Lean elaborates `#check (Proofs.<name> : Spec.<name>)` and `#print axioms`. The output is rejected unless every axiom is one of `propext`, `Classical.choice`, and `Quot.sound`. That catches `sorryAx` and `native_decide` (`Lean.ofReduceBool`) even when the source scan is not enough.

`#print axioms` writes to stdout, in the form `'Theorem' depends on axioms: [propext]`. A theorem that depends on no axioms prints `does not depend on any axioms`. The parser accepts both, and rejects a line that adds `sorryAx`.

`lean-action` can also run `axiom-audit`, which inspects the compiled environment. This repo uses `#print axioms` instead, because that is the check the gate is supposed to show, and the same script owns the lock and the manifest.

`.github/CODEOWNERS` names `LeanSafetyGate/Spec.lean`, `REQUIREMENTS.md`, and `spec.lock`. GitHub requests a review only when each owner is a real account or team login.

## Phase 4 — differential tests

No new Lean dependency. `Lean.Data.Json` is in the toolchain. `FromJson (Array α)` exists; `FromJson (List α)` does not, so the executable decodes `Array Inputs` and calls `toList`. `Json.compress` is in `Lean.Data.Json.Printer`, which `Lean.Data.Json` imports. A parse error goes to stderr and the process returns 1. The message from a non-JSON stdin starts with `offset 0:`.

`lakefile.toml` adds a `[[lean_exe]]` named `safety-gate`, rooted at `LeanSafetyGate.Main`, and lists it in `defaultTargets`. `lake build` and the gate therefore build the binary. The tests call `.lake/build/bin/safety-gate` directly. `lake exe` would pay for a Lake startup on every example.

`python/controller.py` reimplements `guardsOk`, `nextLatch`, and `step`. It is not generated from the Lean file. `pytest` 8.4.2 and `hypothesis` 6.141.1 are pinned in `python/requirements.txt`. CI installs them with `actions/setup-python` 3.12 after `lean-action`, so `lake` is still on `PATH` when the fixture builds the executable.

The property test sets `database=None`. Hypothesis otherwise tries to write `.hypothesis/examples`, and that path is unusable in some sandboxes, which becomes a warning rather than a saved corpus. A failing example is still printed. `.hypothesis` is gitignored in case a local run creates it.
