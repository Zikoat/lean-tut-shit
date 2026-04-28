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

#eval show IO Unit from do
  let w_0 : World := { ticks := 400, myPos := {x:=3}}
  saveWorld w_0 "test_world.json"
  let w_1 <- loadWorld "test_world.json"
  unless w_0 == w_1 do
    throw (IO.userError s!"roundtrip mismatch:\n  before: {repr w_0}\n  after:{repr w_1}")

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
