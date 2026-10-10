# Lean Safety Gate

A small, agent-written model of a machine-cell safety controller, checked by the Lean 4 kernel. The repository is a worked example of the workflow below. It is a learning demo, not a certification, and it does not claim compliance with IEC 61508, ISO 13849, or any other safety standard.

## How the pieces fit

English requirements in `REQUIREMENTS.md` are formalized as named propositions in `LeanSafetyGate/Spec.lean`. Each proposition is a statement about every input trace from the initial state, not about a single scan. `LeanSafetyGate/Model.lean` is an executable candidate for that spec: `step` is one scan, and `run` walks a trace.

`LeanSafetyGate/Proofs.lean` has one theorem per proposition, and each theorem's type is exactly that proposition, so the claim cannot be quietly reworded to match a proof. CI rejects a failed build, a `sorry`, `admit`, or `axiom` in the Lean sources, a theorem that depends on axioms other than `propext`, `Classical.choice`, and `Quot.sound`, a specification proposition with no matching theorem, and a change to `LeanSafetyGate/Spec.lean` whose SHA-256 was not written into `spec.lock`. A separate implementation, in Python, is meant to be checked against the same traces.

The e-stop latch in the specification is defined from the inputs again, not by calling the model's latch update. Changing the controller does not silently change the requirement.

Versions, setup commands, and the problems hit so far are in `docs/STACK.md`.

## Status

| Stage | Where it lives | State |
| --- | --- | --- |
| Toolchain and language-server access | `lean-toolchain`, `.cursor/mcp.json` | Done |
| Requirements, model, spec | `REQUIREMENTS.md`, `LeanSafetyGate/Model.lean`, `LeanSafetyGate/Spec.lean` | Written |
| Proofs | `LeanSafetyGate/Proofs.lean` | One theorem per specification proposition |
| CI gate | `.github/workflows/lean_action_ci.yml`, `scripts/gate.sh` | Build, source scan, axiom check, spec lock, and manifest |
| Differential tests | not in the tree yet | Not started |

## Run

Install [elan](https://github.com/leanprover/elan) if `lake` is not on your `PATH`, then from this directory:

```sh
lake build
```

The toolchain file selects the Lean version. The package does not depend on Mathlib.

The same checks CI runs locally:

```sh
bash scripts/gate.sh
```

`spec.manifest` lists every `def <name> : Prop` in the specification. The gate elaborates a theorem of that name at type `Spec.<name>` and prints its axioms with `#print axioms`. `spec.lock` is the SHA-256 of `LeanSafetyGate/Spec.lean`. A specification edit is reviewable only when that hash changes in the same commit. `.github/CODEOWNERS` names the same files.
