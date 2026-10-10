"""Production scan of the machine-cell controller.

Separate implementation of `LeanSafetyGate.Model`. The differential tests
check that the two agree on the same traces. This file is not generated
from the Lean source.
"""


def guards_ok(inp):
    return inp["guardDoorClosed"] and inp["lightCurtainClear"] and not inp["emergencyStop"]


def next_latch(was_latched, inp):
    if inp["emergencyStop"]:
        return True
    if was_latched:
        return not inp["resetPressed"]
    return False


def step(state, inp):
    latched = next_latch(state["estopLatched"], inp)
    if latched or not guards_ok(inp):
        enable = False
    elif inp["startPressed"]:
        enable = True
    else:
        enable = state["motorEnable"]
    return {"estopLatched": latched, "motorEnable": enable}


INIT = {"estopLatched": False, "motorEnable": False}


def run(trace):
    state = dict(INIT)
    outputs = []
    for inp in trace:
        state = step(state, inp)
        outputs.append({"motorEnable": state["motorEnable"]})
    return outputs
