# Lean Safety Gate

A small, agent-written model of a machine-cell safety controller, checked by the Lean 4 kernel. The point of the repository is the workflow: requirements, a formal specification, an executable model, proofs, a CI gate that rejects unproven or weakened claims, and differential tests against a separate implementation. Later phases add those pieces one at a time.

This is a learning demo. It is not a certification and it does not claim compliance with IEC 61508, ISO 13849, or any other safety standard.

## How the pieces fit

Requirements (plain English) are turned into named propositions over whole input traces. An executable `step` function is a candidate controller. Proofs, once they exist, are theorems whose types are exactly those propositions, so the claim cannot be quietly reworded to match a proof. CI is meant to refuse a build that still contains `sorry`, extra axioms, or a specification change that was not explicitly locked. A separate Python controller is meant to be checked against the same traces.

| Stage | Where it will live | State |
| --- | --- | --- |
| Toolchain and language-server access | `lean-toolchain`, `.cursor/mcp.json`, `docs/STACK.md` | Phase 0, this branch |
| Requirements, model, unproved spec | `REQUIREMENTS.md`, `LeanSafetyGate/` | Not started |
| Proofs | `LeanSafetyGate/Proofs.lean` | Not started |
| CI gate | `.github/workflows/` | Not started. The workflow in the tree now is only the Lake template's build |
| Differential tests | Python, later | Not started |

`docs/STACK.md` records versions, setup commands, and the problems hit while bringing the toolchain up.

## Run

Install [elan](https://github.com/leanprover/elan) if `lake` is not on your `PATH`, then from this directory:

```sh
lake build
```

The toolchain file selects Lean 4.34.1. The package does not depend on Mathlib.
