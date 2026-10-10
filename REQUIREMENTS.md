# Requirements

Plain-English requirements for the machine-cell controller. Each R-number is formalized as a named proposition in `LeanSafetyGate/Spec.lean`. Those propositions are not proved yet.

This is a learning demo. It is not a certification and it does not claim compliance with IEC 61508, ISO 13849, or any other safety standard.

## What a cycle is

The controller is cyclic, like a safety PLC scan. Each cycle it reads one record of inputs and produces one `motorEnable`. There is no clock, debounce, or reaction-time bound. "At the same time" means "in the same input record."

The propositions quantify over every finite list of input records, starting from the initial state below. A property of one cycle in isolation is not enough.

## Inputs and output

All five inputs are booleans in one record.

| Field | `true` means |
| --- | --- |
| `emergencyStop` | The e-stop is pressed |
| `guardDoorClosed` | The guard door is closed |
| `lightCurtainClear` | The light curtain is clear (the beam is not broken) |
| `resetPressed` | Reset is pressed on this cycle |
| `startPressed` | Start is pressed on this cycle |

The only output is `motorEnable`. `true` means the motor is allowed to run on that cycle.

`guardDoorClosed` and `lightCurtainClear` are named for the safe polarity. `emergencyStop` is named for the pressed, unsafe polarity.

## Initial state

Power-up is stopped and not latched: `motorEnable` is false, and the e-stop latch is clear. The first cycle is an ordinary cycle. Nothing is remembered from before the trace.

## Requirements

### R1 — Motor only while the guards are healthy

On any cycle where `motorEnable` is true, that same cycle's inputs have the door closed, the light curtain clear, and the e-stop not pressed.

A start command does not override this. If the door is open, the curtain is broken, or the e-stop is pressed, the motor is not enabled on that cycle, whether or not start is pressed.

### R2 — E-stop latch

Pressing the e-stop sets a latch. While the latch is set, `motorEnable` is false.

The latch becomes clear only on a cycle where the e-stop is not pressed and reset is pressed. Both have to be true in that cycle's input record. Reset while the e-stop is still pressed does not clear the latch. Releasing the e-stop without reset does not clear it either.

Reset only clears the latch. It is not a start. After the clearing cycle, the motor stays off until a start command that R5 accepts.

The latch is tracked from the inputs, starting clear at power-up. Opening the door or breaking the light curtain does not set it, and does not clear it.

### R3 — No automatic restart

The motor is enabled on a cycle only if it was already enabled on the previous cycle, or start is pressed on this cycle. The first cycle has no previous cycle, so the motor can be enabled then only if start is pressed.

In particular, a trip (e-stop pressed, door not closed, or light curtain not clear) forces the motor off, and the motor stays off after the inputs become healthy again until a later cycle in which start is pressed. The inputs returning to normal is not enough.

Start is level-sensitive in this version: if `startPressed` is true on a cycle that is otherwise allowed to run, that counts as the fresh start, even if it was also true on the previous cycle. See PROPOSED P1.

### R4 — Start is ignored while the e-stop latch is set

If the e-stop latch is set on a cycle, `motorEnable` is false on that cycle even when start is pressed.

"Latched" here means the e-stop latch from R2, including a cycle where the e-stop has already been released but reset has not been pressed yet. The door and the light curtain are not latched faults. While either is unhealthy, R1 already keeps the motor off. Once both are healthy again and the e-stop latch is clear, start is accepted without a reset.

### R5 — Start enables the motor when nothing is stopping it

If, on a cycle, the e-stop latch is clear, the door is closed, the light curtain is clear, the e-stop is not pressed, and start is pressed, then `motorEnable` is true.

This includes the cycle that clears the latch: if that same record has the e-stop released, reset pressed, and start pressed, the latch ends the cycle clear and the start is honored. See PROPOSED P2, which would reject that same-cycle start.

R5 is what stops a controller that never enables the motor from satisfying R1–R4.

### R6 — The motor holds while it is safe

If the motor was enabled on the previous cycle, and this cycle the e-stop latch is clear, the door is closed, the light curtain is clear, and the e-stop is not pressed, then the motor stays enabled even if start is not pressed.

Start is a momentary command, not a hold-to-run control. The motor does not drop just because the start button was released.

## PROPOSED

These are not in `LeanSafetyGate/Spec.lean`. They are not claims the model has to meet until they are accepted and given R-numbers.

- **P1 — Rising-edge start.** A start button that is already pressed when a trip clears must not count as the fresh start. Otherwise an operator who holds start through a door opening restarts the motor the moment the door closes.
- **P2 — Reset and start are separate cycles.** A start in the same cycle as the reset that clears the e-stop latch is ignored. R5 currently honors it.
- **P3 — Power-up latch.** The e-stop latch is set at power-up until a reset with the e-stop released. The model currently powers up clear and stopped.
- **P4 — Left out of this demo.** No reaction-time bound, no dual-channel inputs, no discrepancy diagnostics, no wiring model, no claim about what the motor contactor does when `motorEnable` is false.

## Ambiguities closed here

- **Safe polarity of the booleans.** The informal "guardDoor (closed or not)" and "lightCurtain (clear or broken)" do not say which boolean value is safe. The field names fix that.
- **Same-cycle reset.** "Released AND reset" is one input record, not two events in a required order across cycles. Reset is ignored if the e-stop is pressed in that same record.
- **Which trips latch.** Only the e-stop sets the reset latch. Door and curtain trips need a new start, not a reset.
- **Momentary start.** The motor keeps running after start is released, until a trip. It does not need the button held down.
- **Always-off would be "safe".** R5 and R6 say the motor does turn on, and stays on, when the conditions hold. R1–R4 alone do not.
