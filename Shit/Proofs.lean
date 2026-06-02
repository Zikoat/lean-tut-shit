import Mathlib.Tactic
import Shit.World

inductive Prog where
| skip : Prog
| seq : Prog → Prog → Prog
| while : Bool → Prog → Prog


inductive Terminates : Prog → Type where
| skip : Terminates Prog.skip
| seq (p q : Prog) :
    Terminates p → Terminates q → Terminates (Prog.seq p q)
| while_done (body : Prog) : Terminates (Prog.while false body)
| while_step (body : Prog) :
    Terminates (Prog.seq body (Prog.while true body)) →
    Terminates (Prog.while true body)

def whileTrue : Prog :=
  Prog.while true Prog.skip

def termSize : {p: Prog} → Terminates p → Nat
| _, Terminates.skip => 1
| _, Terminates.while_done _ => 1
| _, Terminates.seq _ _ hp hq => termSize hp + termSize hq + 1
| _, Terminates.while_step _ hseq => termSize hseq + 1

theorem whileTrue_never_terminates (h : Terminates whileTrue ): false := by
  cases h with
  | while_step body hseq =>
    cases hseq with
    | seq p q hp hq =>
      exact whileTrue_never_terminates hq
termination_by termSize h
decreasing_by
  rename_i hEq hseqEq
  cases hEq
  cases hseqEq
  simp [termSize]
  simpa [Nat.add_assoc, Nat.add_left_comm, Nat.add_comm] using
  (Nat.le_add_right (termSize hq) (termSize hp + 1))

-- The `World` JSON roundtrip `#eval` lives in `Shit.WorldRoundtrip` (not here):
-- it writes a file at elaboration time, and the comparator compiles this module
-- (via `Challenge.lean`) inside a landrun FS sandbox that denies such writes.

partial def exec : Prog -> IO Unit
| .skip => pure ()
| .seq p q => do
  exec p
  exec q
| .while cond body => do
  if cond then
    exec (.seq body (.while cond body))
  else
    pure ()

def sleepTest :IO Unit :=do
  IO.println "start"
  exec whileTrue
  -- while true do
  --   IO.sleep 1000
  --   IO.println "sleeping"


-- def main : IO Unit := do
--   sleepTest

-- when we move outside of the world we should end at the other side
-- a world with size 2x2, my location is 0,0, then we move left and we should end up on the other side.
example : (({} : World)).myPos.x = 0 := by rfl
example : (move .west ({} : World)).myPos.x = 0 := by rfl
example : (move .east ({} : World)).myPos.x = 0 := by rfl
example : (move .north ({} : World)).myPos.x = 0 := by rfl
example : (move .south ({} : World)).myPos.x = 0 := by rfl
example : (move .north ({unlocked_expand_1:=true} : World)).myPos.y = 1 := by rfl
example : (move .south ({unlocked_expand_1:=true} : World)).myPos.y = 2 := by rfl
example : (move .north (move .north ({unlocked_expand_1:=true} : World))).myPos.y = 2 := by rfl
example : (move .north (move .north (move .north ({unlocked_expand_1:=true} : World)))).myPos.y = 0 := by rfl
example : (world_size ({unlocked_expand_1:=true} : World)).y = 3 := by rfl

theorem x_less_than_world_x (w : World) : w.myPos.x < (world_size w).x :=
  w.myPos_valid.1
theorem y_less_than_world_y (w : World) : w.myPos.y < (world_size w).y :=
  w.myPos_valid.2
theorem x_more_than_0 (w : World) : w.myPos.x >= 0 := by omega
theorem y_more_than_0 (w : World) : w.myPos.y >= 0 := by omega

/-- Proposition for the `contrapositive` Challenge: the statement type only.
    The proof is an open Challenge (see `Shit/Challenges/Contrapositive/`). -/
def Contrapositive (p q : Prop) : Prop := (p → q) → (¬q → ¬p)
