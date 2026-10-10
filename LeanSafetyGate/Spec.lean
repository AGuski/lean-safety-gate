/-
Requirements from `REQUIREMENTS.md` as propositions.

Each `def` below is a `Prop`, not a theorem. Nothing in this file is proved.
Every proposition quantifies over whole input traces run from `init`.
-/
import LeanSafetyGate.Model

namespace LeanSafetyGate.Spec

/-- Latch required by R2, computed from the inputs alone.

A press sets it. On any other cycle a set latch clears only when reset is
pressed (the e-stop is already known to be released, because this branch is
the `else`). Power-up contributes the starting value `false`, from `latchTrace`.
This is not `Model.nextLatch`. The two are written out separately so a change
to the controller does not rewrite the requirement.
-/
def latchAfter (wasLatched : Bool) (inp : Inputs) : Bool :=
  if inp.emergencyStop then
    true
  else if wasLatched then
    !inp.resetPressed
  else
    false

def latchTraceFrom (wasLatched : Bool) : List Inputs → List Bool
  | [] => []
  | inp :: rest =>
    let now := latchAfter wasLatched inp
    now :: latchTraceFrom now rest

/-- E-stop latch after each cycle of `trace`, starting from a clear latch. -/
def latchTrace (trace : List Inputs) : List Bool :=
  latchTraceFrom false trace

/-- `motorEnable` after cycle `i` of `trace`, or `none` if the trace is shorter. -/
def motorAt (trace : List Inputs) (i : Nat) : Option Bool :=
  match (run init trace)[i]? with
  | some out => some out.motorEnable
  | none => none

/-- R1. Whenever the motor is enabled, that cycle's door is closed, the light
curtain is clear, and the e-stop is not pressed. -/
def motorOnlyWhenSafe : Prop :=
  ∀ trace : List Inputs, ∀ i : Nat,
    motorAt trace i = some true →
    ∃ inp : Inputs, trace[i]? = some inp ∧
      inp.guardDoorClosed = true ∧
      inp.lightCurtainClear = true ∧
      inp.emergencyStop = false

/-- R2. While the e-stop latch is set, the motor is not enabled.

The latch is `latchTrace`: set by a press, and clear only on a later cycle
whose e-stop is released and whose reset is pressed. Door and curtain trips
do not set it. -/
def estopLatchHoldsUntilReset : Prop :=
  ∀ trace : List Inputs, ∀ i : Nat,
    (latchTrace trace)[i]? = some true →
    motorAt trace i = some false

/-- R3. The motor becomes enabled only on a cycle where start is pressed.

"Becomes enabled" includes the first cycle. A motor that was already enabled
may stay enabled without start still being pressed. So a door that closes
again, or a curtain that clears, does not by itself produce `motorEnable`. -/
def noAutomaticRestart : Prop :=
  ∀ trace : List Inputs, ∀ i : Nat,
    motorAt trace i = some true →
    (i = 0 ∨ motorAt trace (i - 1) = some false) →
    ∃ inp : Inputs, trace[i]? = some inp ∧ inp.startPressed = true

/-- R4. A start command does not enable the motor while the e-stop latch is set.

This is the start-button reading of R2. It still names start, so a later edit
cannot treat "start clears the latch" as meeting the requirement. -/
def startIgnoredWhileLatched : Prop :=
  ∀ trace : List Inputs, ∀ i : Nat, ∀ inp : Inputs,
    trace[i]? = some inp →
    (latchTrace trace)[i]? = some true →
    inp.startPressed = true →
    motorAt trace i = some false

/-- R5. Start enables the motor when the latch is clear and the guards are healthy.

The latch value is the one after this cycle's inputs, so the cycle that
clears the latch with reset can also honor start. Reset without start does
not satisfy the antecedent. -/
def startEnablesWhenClear : Prop :=
  ∀ trace : List Inputs, ∀ i : Nat, ∀ inp : Inputs,
    trace[i]? = some inp →
    (latchTrace trace)[i]? = some false →
    inp.guardDoorClosed = true →
    inp.lightCurtainClear = true →
    inp.emergencyStop = false →
    inp.startPressed = true →
    motorAt trace i = some true

/-- R6. An enabled motor stays enabled while the latch is clear and the guards
stay healthy, even if start is not pressed. -/
def motorHoldsWhileSafe : Prop :=
  ∀ trace : List Inputs, ∀ i : Nat, ∀ inp : Inputs,
    0 < i →
    trace[i]? = some inp →
    motorAt trace (i - 1) = some true →
    (latchTrace trace)[i]? = some false →
    inp.guardDoorClosed = true →
    inp.lightCurtainClear = true →
    inp.emergencyStop = false →
    motorAt trace i = some true

end LeanSafetyGate.Spec
