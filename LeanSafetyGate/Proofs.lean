/-
Proofs that the executable controller meets `LeanSafetyGate.Spec`.

Each theorem's type is exactly one proposition from that file. The arguments are
whole traces. The induction carries the controller's memory (`State`) and the
specification's latch, and shows they stay in step.
-/
import LeanSafetyGate.Spec

namespace LeanSafetyGate.Proofs

open LeanSafetyGate

theorem nextLatch_eq_latchAfter (wasLatched : Bool) (inp : Inputs) :
    nextLatch wasLatched inp = Spec.latchAfter wasLatched inp := by
  rfl

theorem step_latch (s : State) (inp : Inputs) :
    (step s inp).estopLatched = Spec.latchAfter s.estopLatched inp := by
  simp [step, nextLatch_eq_latchAfter]

/-- `motorEnable` after `step` is true exactly when this scan is allowed to run
and either start is pressed or the motor was already on. -/
theorem step_motor_true_iff (s : State) (inp : Inputs) :
    (step s inp).motorEnable = true ↔
      Spec.latchAfter s.estopLatched inp = false ∧ guardsOk inp = true ∧
        (inp.startPressed = true ∨ s.motorEnable = true) := by
  simp only [step, nextLatch_eq_latchAfter]
  by_cases hL : Spec.latchAfter s.estopLatched inp = true <;>
    by_cases hG : guardsOk inp = true <;>
      by_cases hS : inp.startPressed = true <;>
        by_cases hM : s.motorEnable = true <;>
          simp_all

theorem guardsOk_iff (inp : Inputs) :
    guardsOk inp = true ↔
      inp.guardDoorClosed = true ∧ inp.lightCurtainClear = true ∧
        inp.emergencyStop = false := by
  simp [guardsOk, and_assoc]

theorem step_motor_false_of_latch (s : State) (inp : Inputs)
    (h : Spec.latchAfter s.estopLatched inp = true) :
    (step s inp).motorEnable = false := by
  cases hM : (step s inp).motorEnable with
  | false => rfl
  | true =>
      have hiff := (step_motor_true_iff s inp).mp hM
      rw [h] at hiff
      cases hiff.1

/-- Motor output of cycle `i`, starting from an arbitrary state. `Spec.motorAt` is the case `s = init`. -/
def motorAtFrom (s : State) (trace : List Inputs) (i : Nat) : Option Bool :=
  match (run s trace)[i]? with
  | some out => some out.motorEnable
  | none => none

theorem motorAt_eq (trace : List Inputs) (i : Nat) :
    Spec.motorAt trace i = motorAtFrom init trace i := rfl

@[simp] theorem motorAtFrom_nil (s : State) (i : Nat) : motorAtFrom s [] i = none := by
  simp [motorAtFrom, run]

@[simp] theorem motorAtFrom_zero (s : State) (inp : Inputs) (rest : List Inputs) :
    motorAtFrom s (inp :: rest) 0 = some (step s inp).motorEnable := by
  simp [motorAtFrom, run, toOutput]

@[simp] theorem motorAtFrom_succ (s : State) (inp : Inputs) (rest : List Inputs) (i : Nat) :
    motorAtFrom s (inp :: rest) (i + 1) = motorAtFrom (step s inp) rest i := by
  simp [motorAtFrom, run, List.getElem?_cons_succ]

theorem motor_safe_from (s : State) (trace : List Inputs) :
    ∀ i, motorAtFrom s trace i = some true →
      ∃ inp, trace[i]? = some inp ∧ guardsOk inp = true := by
  induction trace generalizing s with
  | nil =>
      intro i h
      simp at h
  | cons inp rest ih =>
      intro i h
      cases i with
      | zero =>
          simp at h
          have hg := ((step_motor_true_iff s inp).mp h).2.1
          exact ⟨inp, by simp, hg⟩
      | succ j =>
          simp at h
          obtain ⟨inp', hget, hg⟩ := ih (step s inp) j h
          exact ⟨inp', by simpa [List.getElem?_cons_succ] using hget, hg⟩

theorem latch_blocks_from (s : State) (was : Bool) (h0 : s.estopLatched = was)
    (trace : List Inputs) :
    ∀ i, (Spec.latchTraceFrom was trace)[i]? = some true →
      motorAtFrom s trace i = some false := by
  induction trace generalizing s was with
  | nil =>
      intro i h
      simp [Spec.latchTraceFrom] at h
  | cons inp rest ih =>
      intro i h
      cases i with
      | zero =>
          simp [Spec.latchTraceFrom] at h
          have hoff := step_motor_false_of_latch s inp (by simpa [h0] using h)
          simp [hoff]
      | succ j =>
          simp [Spec.latchTraceFrom, List.getElem?_cons_succ] at h
          have hlat : (step s inp).estopLatched = Spec.latchAfter was inp := by
            simpa [h0] using step_latch s inp
          simpa using ih (step s inp) (Spec.latchAfter was inp) hlat j h

/-- The motor was off coming into cycle `i`: the carried state on cycle 0, otherwise the previous output. -/
def prevWasOff (s : State) (trace : List Inputs) : Nat → Prop
  | 0 => s.motorEnable = false
  | j + 1 => motorAtFrom s trace j = some false

theorem needs_start_from (s : State) (trace : List Inputs) :
    ∀ i, motorAtFrom s trace i = some true → prevWasOff s trace i →
      ∃ inp, trace[i]? = some inp ∧ inp.startPressed = true := by
  induction trace generalizing s with
  | nil =>
      intro i h
      simp at h
  | cons head rest ih =>
      intro i hm hprev
      cases i with
      | zero =>
          simp [prevWasOff] at hm hprev
          have hdisj := ((step_motor_true_iff s head).mp hm).2.2
          refine ⟨head, by simp, ?_⟩
          cases hdisj with
          | inl hs => exact hs
          | inr hp =>
              rw [hprev] at hp
              cases hp
      | succ j =>
          simp at hm
          have hprev' : prevWasOff (step s head) rest j := by
            cases j with
            | zero => simpa [prevWasOff] using hprev
            | succ k => simpa [prevWasOff] using hprev
          obtain ⟨inp, hget, hs⟩ := ih (step s head) j hm hprev'
          exact ⟨inp, by simpa [List.getElem?_cons_succ] using hget, hs⟩

theorem start_enables_from (s : State) (was : Bool) (h0 : s.estopLatched = was)
    (trace : List Inputs) :
    ∀ i inp, trace[i]? = some inp →
      (Spec.latchTraceFrom was trace)[i]? = some false →
      inp.guardDoorClosed = true → inp.lightCurtainClear = true →
      inp.emergencyStop = false → inp.startPressed = true →
      motorAtFrom s trace i = some true := by
  induction trace generalizing s was with
  | nil =>
      intro i inp hget
      simp at hget
  | cons head rest ih =>
      intro i inp hget hlatch hdoor hcur hestop hstart
      cases i with
      | zero =>
          simp at hget
          subst hget
          simp [Spec.latchTraceFrom] at hlatch
          have hg := (guardsOk_iff head).mpr ⟨hdoor, hcur, hestop⟩
          have hm : (step s head).motorEnable = true :=
            (step_motor_true_iff s head).mpr ⟨by simpa [h0] using hlatch, hg, Or.inl hstart⟩
          simp [hm]
      | succ j =>
          simp [List.getElem?_cons_succ] at hget
          simp [Spec.latchTraceFrom, List.getElem?_cons_succ] at hlatch
          have hlat : (step s head).estopLatched = Spec.latchAfter was head := by
            simpa [h0] using step_latch s head
          exact ih (step s head) (Spec.latchAfter was head) hlat j inp
            hget hlatch hdoor hcur hestop hstart

theorem holds_from (s : State) (was : Bool) (h0 : s.estopLatched = was)
    (trace : List Inputs) :
    ∀ i inp, 0 < i → trace[i]? = some inp →
      motorAtFrom s trace (i - 1) = some true →
      (Spec.latchTraceFrom was trace)[i]? = some false →
      inp.guardDoorClosed = true → inp.lightCurtainClear = true →
      inp.emergencyStop = false →
      motorAtFrom s trace i = some true := by
  induction trace generalizing s was with
  | nil =>
      intro i inp _ hget
      simp at hget
  | cons head rest ih =>
      intro i inp hi hget hprev hlatch hdoor hcur hestop
      cases i with
      | zero => omega
      | succ j =>
          cases j with
          | zero =>
              simp at hprev
              cases rest with
              | nil => simp at hget
              | cons inp2 rest2 =>
                  simp at hget
                  subst hget
                  simp [Spec.latchTraceFrom] at hlatch
                  have hm : (step (step s head) inp2).motorEnable = true :=
                    (step_motor_true_iff (step s head) inp2).mpr
                      ⟨by simpa [step_latch, h0] using hlatch,
                       (guardsOk_iff inp2).mpr ⟨hdoor, hcur, hestop⟩,
                       Or.inr hprev⟩
                  simp [hm]
          | succ k =>
              have hlat : (step s head).estopLatched = Spec.latchAfter was head := by
                simpa [h0] using step_latch s head
              apply ih (step s head) (Spec.latchAfter was head) hlat (k + 1) inp
                (Nat.succ_pos k)
                (by simpa [List.getElem?_cons_succ] using hget)
                (by simpa using hprev)
                (by simpa [Spec.latchTraceFrom, List.getElem?_cons_succ] using hlatch)
                hdoor hcur hestop

theorem motorOnlyWhenSafe : Spec.motorOnlyWhenSafe := by
  intro trace i hm
  obtain ⟨inp, hget, hg⟩ := motor_safe_from init trace i (by simpa [motorAt_eq] using hm)
  exact ⟨inp, hget, (guardsOk_iff inp).mp hg⟩

theorem estopLatchHoldsUntilReset : Spec.estopLatchHoldsUntilReset := by
  intro trace i hlatch
  simpa [motorAt_eq, Spec.latchTrace] using
    latch_blocks_from init false rfl trace i hlatch

/-- R4 names the start button, and it follows from R2: a latched cycle has the motor off whether or not start is pressed. -/
theorem startIgnoredWhileLatched : Spec.startIgnoredWhileLatched := by
  intro trace i inp _ hlatch _
  exact estopLatchHoldsUntilReset trace i hlatch

theorem noAutomaticRestart : Spec.noAutomaticRestart := by
  intro trace i hm hcond
  have hm' : motorAtFrom init trace i = some true := by simpa [motorAt_eq] using hm
  have hprev : prevWasOff init trace i := by
    cases i with
    | zero => rfl
    | succ j =>
        cases hcond with
        | inl h0 => cases h0
        | inr h => simpa [prevWasOff, motorAt_eq] using h
  obtain ⟨inp, hget, hs⟩ := needs_start_from init trace i hm' hprev
  exact ⟨inp, hget, hs⟩

theorem startEnablesWhenClear : Spec.startEnablesWhenClear := by
  intro trace i inp hget hlatch hdoor hcur hestop hstart
  simpa [motorAt_eq, Spec.latchTrace] using
    start_enables_from init false rfl trace i inp hget hlatch hdoor hcur hestop hstart

theorem motorHoldsWhileSafe : Spec.motorHoldsWhileSafe := by
  intro trace i inp hi hget hprev hlatch hdoor hcur hestop
  simpa [motorAt_eq, Spec.latchTrace] using
    holds_from init false rfl trace i inp hi hget (by simpa [motorAt_eq] using hprev)
      hlatch hdoor hcur hestop

end LeanSafetyGate.Proofs
