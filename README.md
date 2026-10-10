# Lean Safety Gate

A small, agent-written model of a machine-cell safety controller, checked by the Lean 4 kernel. The repository is a worked example of the workflow below. It is a learning demo, not a certification, and it does not claim compliance with IEC 61508, ISO 13849, or any other safety standard.

## How the pieces fit

English requirements in `REQUIREMENTS.md` are formalized as named propositions in `LeanSafetyGate/Spec.lean`. Each proposition is a statement about every input trace from the initial state, not about a single scan. `LeanSafetyGate/Model.lean` is an executable candidate for that spec: `step` is one scan, and `run` walks a trace.

Proofs are not written yet. When they are, each one has to be a theorem whose type is exactly one of those propositions, so the claim cannot be quietly reworded to match a proof. Later, CI is meant to reject `sorry`, axioms beyond Lean's standard three, and a specification change that was not explicitly locked. A separate implementation, in Python, is meant to be checked against the same traces.

The e-stop latch in the specification is defined from the inputs again, not by calling the model's latch update. Changing the controller does not silently change the requirement.

Versions, setup commands, and the problems hit so far are in `docs/STACK.md`.

## Status

| Stage | Where it lives | State |
| --- | --- | --- |
| Toolchain and language-server access | `lean-toolchain`, `.cursor/mcp.json` | Done |
| Requirements, model, unproved spec | `REQUIREMENTS.md`, `LeanSafetyGate/` | Written. Nothing is proved |
| Proofs | not in the tree yet | Not started |
| CI gate | `.github/workflows/lean_action_ci.yml` | Lake's template build only. The sorry, axiom, and spec-lock checks are not started |
| Differential tests | not in the tree yet | Not started |

## Run

Install [elan](https://github.com/leanprover/elan) if `lake` is not on your `PATH`, then from this directory:

```sh
lake build
```

The toolchain file selects the Lean version. The package does not depend on Mathlib.
