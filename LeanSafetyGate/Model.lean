/-
Executable scan of the machine-cell controller.

`step` reads one input record and updates the state. `run` feeds it a whole
trace from a given starting state. The requirements this function is supposed
to meet live in `LeanSafetyGate/Spec.lean` and are not proved here.
-/
namespace LeanSafetyGate

/-- One scan's inputs. See `REQUIREMENTS.md` for the polarity of each field. -/
structure Inputs where
  /-- `true` when the e-stop is pressed. -/
  emergencyStop : Bool
  /-- `true` when the guard door is closed. -/
  guardDoorClosed : Bool
  /-- `true` when the light curtain is clear. -/
  lightCurtainClear : Bool
  resetPressed : Bool
  startPressed : Bool
  deriving Repr, DecidableEq

/-- The only actuator command this demo models. -/
structure Output where
  motorEnable : Bool
  deriving Repr, DecidableEq

/-- Memory carried from one scan to the next. -/
structure State where
  /-- Set by an e-stop press. Cleared only when the e-stop is released and reset is pressed. -/
  estopLatched : Bool
  motorEnable : Bool
  deriving Repr, DecidableEq

/-- Power-up: stopped, and the e-stop latch clear. -/
def init : State where
  estopLatched := false
  motorEnable := false

def toOutput (s : State) : Output where
  motorEnable := s.motorEnable

/-- Door closed, curtain clear, e-stop not pressed. -/
def guardsOk (inp : Inputs) : Bool :=
  inp.guardDoorClosed && inp.lightCurtainClear && !inp.emergencyStop

/-- Next e-stop latch. A press sets it. Otherwise a set latch clears only if reset is pressed. -/
def nextLatch (wasLatched : Bool) (inp : Inputs) : Bool :=
  if inp.emergencyStop then
    true
  else if wasLatched then
    !inp.resetPressed
  else
    false

/-- One scan. The latch is updated before the motor decision, so a reset and a start in the same record can both take effect. -/
def step (s : State) (inp : Inputs) : State :=
  let latched := nextLatch s.estopLatched inp
  let enable :=
    if latched || !guardsOk inp then
      false
    else if inp.startPressed then
      true
    else
      s.motorEnable
  { estopLatched := latched, motorEnable := enable }

/-- Outputs for each input, in order, starting from `s`. The empty trace produces no outputs. -/
def run (s : State) : List Inputs → List Output
  | [] => []
  | inp :: rest =>
    let s' := step s inp
    toOutput s' :: run s' rest

/-
Executable checks of the informal scenarios. These are evaluations, not proofs
of the propositions in `Spec.lean`.
-/
private def inputs (emergencyStop guardDoorClosed lightCurtainClear resetPressed startPressed : Bool) : Inputs :=
  { emergencyStop, guardDoorClosed, lightCurtainClear, resetPressed, startPressed }

private def motors (trace : List Inputs) : List Bool :=
  (run init trace).map (·.motorEnable)

-- Healthy start.
#guard motors [inputs false true true false true] == [true]

-- Start while the door is open does nothing.
#guard motors [inputs false false true false true] == [false]

-- E-stop, then release without reset, then start: still off.
#guard motors
    [inputs true true true false false,
     inputs false true true false false,
     inputs false true true false true] ==
  [false, false, false]

-- E-stop, then release, reset, and start in one record: motor comes on.
#guard motors
    [inputs true true true false false,
     inputs false true true true true] ==
  [false, true]

-- Reset while the e-stop is still pressed does not clear the latch.
#guard motors
    [inputs true true true true true,
     inputs false true true false true] ==
  [false, false]

-- Running, door opens, door closes again: stays off until a new start.
#guard motors
    [inputs false true true false true,
     inputs false false true false false,
     inputs false true true false false,
     inputs false true true false true] ==
  [true, false, false, true]

-- A light-curtain break is a trip, not an e-stop latch: start recovers it, reset is not required.
#guard motors
    [inputs false true true false true,
     inputs false true false false false,
     inputs false true true false true] ==
  [true, false, true]

-- Start is momentary: the motor stays on after the button is released.
#guard motors
    [inputs false true true false true,
     inputs false true true false false] ==
  [true, true]

end LeanSafetyGate
