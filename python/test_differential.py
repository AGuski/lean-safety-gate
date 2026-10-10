"""Check the Python controller against the Lean executable on the same traces."""

import json
import os
import subprocess
from pathlib import Path

import pytest
from hypothesis import given, settings
from hypothesis import strategies as st

from controller import run

ROOT = Path(__file__).resolve().parents[1]
FIELDS = (
    "emergencyStop",
    "guardDoorClosed",
    "lightCurtainClear",
    "resetPressed",
    "startPressed",
)

inputs = st.fixed_dictionaries({name: st.booleans() for name in FIELDS})


def lake_env():
    env = os.environ.copy()
    elan = Path.home() / ".elan" / "bin"
    if elan.is_dir():
        env["PATH"] = str(elan) + os.pathsep + env.get("PATH", "")
    return env


@pytest.fixture(scope="session")
def safety_gate():
    env = lake_env()
    subprocess.run(["lake", "build", "safety-gate"], cwd=ROOT, check=True, env=env)
    binary = ROOT / ".lake" / "build" / "bin" / "safety-gate"
    assert binary.is_file()
    return binary, env


def lean_outputs(safety_gate, trace):
    binary, env = safety_gate
    proc = subprocess.run(
        [binary],
        input=json.dumps(trace),
        text=True,
        capture_output=True,
        check=True,
        env=env,
    )
    return json.loads(proc.stdout)


def record(emergency_stop, door_closed, curtain_clear, reset, start):
    return {
        "emergencyStop": emergency_stop,
        "guardDoorClosed": door_closed,
        "lightCurtainClear": curtain_clear,
        "resetPressed": reset,
        "startPressed": start,
    }


@pytest.mark.parametrize(
    ("trace", "expected"),
    [
        ([], []),
        ([record(False, True, True, False, True)], [{"motorEnable": True}]),
        ([record(False, False, True, False, True)], [{"motorEnable": False}]),
        (
            [
                record(True, True, True, False, False),
                record(False, True, True, False, False),
                record(False, True, True, False, True),
            ],
            [{"motorEnable": False}, {"motorEnable": False}, {"motorEnable": False}],
        ),
        (
            [
                record(True, True, True, False, False),
                record(False, True, True, True, True),
            ],
            [{"motorEnable": False}, {"motorEnable": True}],
        ),
    ],
)
def test_known_traces(safety_gate, trace, expected):
    assert run(trace) == expected
    assert lean_outputs(safety_gate, trace) == expected


@given(st.lists(inputs, max_size=30))
@settings(max_examples=100, deadline=None, database=None)
def test_random_traces_agree(safety_gate, trace):
    assert run(trace) == lean_outputs(safety_gate, trace)


def test_invalid_json_exits_nonzero(safety_gate):
    binary, env = safety_gate
    proc = subprocess.run(
        [binary],
        input="not json",
        text=True,
        capture_output=True,
        env=env,
    )
    assert proc.returncode != 0
    assert proc.stderr.strip()
