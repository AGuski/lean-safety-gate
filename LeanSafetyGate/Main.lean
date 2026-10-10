/-
Read one trace from stdin and print the motor outputs.

The trace is a JSON array of input records. Each record uses the field names
from `Inputs`, and each boolean is JSON `true` or `false`:

```json
[{"emergencyStop": false, "guardDoorClosed": true, "lightCurtainClear": true,
  "resetPressed": false, "startPressed": true}]
```

Stdout is a JSON array of `{"motorEnable": ...}`, one element per input, from
`run init`. A parse error is written to stderr and the process exits non-zero.
-/
import LeanSafetyGate.Model
import Lean.Data.Json

open LeanSafetyGate
open Lean

instance : FromJson Inputs where
  fromJson? j := do
    let emergencyStop ← j.getObjValAs? Bool "emergencyStop"
    let guardDoorClosed ← j.getObjValAs? Bool "guardDoorClosed"
    let lightCurtainClear ← j.getObjValAs? Bool "lightCurtainClear"
    let resetPressed ← j.getObjValAs? Bool "resetPressed"
    let startPressed ← j.getObjValAs? Bool "startPressed"
    return { emergencyStop, guardDoorClosed, lightCurtainClear, resetPressed, startPressed }

instance : ToJson Output where
  toJson out := Json.mkObj [("motorEnable", toJson out.motorEnable)]

def decodeTrace (text : String) : Except String (Array Inputs) := do
  fromJson? (← Json.parse text)

def main : IO UInt32 := do
  let text ← (← IO.getStdin).readToEnd
  match decodeTrace text with
  | .error err =>
      IO.eprintln err
      return 1
  | .ok inputs =>
      IO.println (toJson (run init inputs.toList)).compress
      return 0
