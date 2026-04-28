import Mathlib.Tactic
import Init.Control.State

def boolArray : Array Bool :=
  #[false, false, false]

-- #eval boolArray[0]
-- #eval boolArray[3]?

def toggleFirst (xs: List Bool):List Bool:=
match xs with
| y::ys => not y :: ys
|[]=>[]

-- #check []
example:toggleFirst []=[]:=by rfl
example:toggleFirst [false]=[true]:=by rfl
example:toggleFirst [true]=[false]:=by rfl
example:toggleFirst [true, true]=[false, true]:=by rfl

def toggleNth2 (xs:List Bool) (n:Nat) : List Bool:=
match n with
| Nat.zero => toggleFirst xs
| Nat.succ n' =>
  match xs with
  | [] => []
  | y::ys=>y::toggleNth2 ys n'

def toggleNth (xs:List Bool) (n:Nat) : List Bool:=
match n, xs with
| 0, [] => []
| 0, y::ys => (not y) :: ys
| Nat.succ _, [] => []
| Nat.succ n',y::ys=>y::toggleNth ys n'

-- #eval toggleNth [true, false, true] 1

example:toggleNth [] 0 = [] := by rfl
example:toggleNth [] 1 = [] := by rfl
example:toggleNth [true] 0 = [false] := by rfl
example:toggleNth [true] 1 = [true] := by rfl
example:toggleNth [true, true] 1 = [true, false] := by rfl
example:toggleNth [false, false, true] 1 = [false, true, true] := by rfl

def toggleNthProperty (xs : List Bool) (n:Nat):Bool:=
match xs[n]? with
|none => true
|some oldVal =>
  match (toggleNth xs n)[n]? with
  | some newVal => newVal != oldVal
  | none => false

-- #eval toggleNthProperty [true] 0
-- #eval toggleNthProperty [] 0
-- #eval toggleNthProperty [] 1
-- #eval toggleNthProperty [false] 1
-- #eval toggleNthProperty [false, true] 1
-- #eval toggleNthProperty [false, true] 1

def ToggleNthProp (xs : List Bool) (n:Nat):Prop:=
toggleNthProperty xs n = true

-- #check ToggleNthProp
-- #check ToggleNthProp [true,false] 1
example:ToggleNthProp [true,false] 1:=by {rfl}

-- example:ToggleNthProp [false,false] 1:=by
-- {
--   sorry
-- }
-- example:2=2:=by sorry


theorem get?_toggleNth
  (xs:List Bool) (n:Nat) (b: Bool)
  : xs[n]? = some b  -- assuming that n is in xs, call the element b
  -> (toggleNth xs n)[n]? = some (not b) -- when we toggle it, it is the opposite of b
  :=
by{
  intro h
  induction n generalizing xs with
  |zero =>
    cases xs with
    |nil=>
      cases h
    |cons y ys =>
      cases h
      rfl
  |succ n' ih =>
    cases xs with
    |nil=>
      cases h
    |cons y ys=>
      simp [toggleNth] at *
      exact ih ys h
}


-- #check get?_toggleNth

theorem toggleNth_length_same
  (xs:List Bool) (n:Nat):
  xs.length = (toggleNth xs n).length :=
by {
  induction n generalizing xs with
  | zero =>
    cases xs with
    | nil =>
      rfl
    | cons y ys =>
      rfl
  | succ k ih =>
    cases xs with
    | nil=>
      rfl
    | cons y ys=>
      simp [toggleNth]
      exact ih ys
}

def setXIfCoordinateIsSame (x:Nat) (x': Nat) (a: String)  :  String :=
  if x = x' then
    "x"
  else
    a

def drawBoard (board: List (List String)) (x:  Nat) (y: Nat) : String :=
  String.intercalate "\n" ((
      board.mapIdx fun y' row =>
        if y < board.length ∧ y' = (board.length - y - 1) then
          row.mapIdx (setXIfCoordinateIsSame x)
        else
          row
    ).map (String.intercalate " "))

def myMainProgram : IO Unit := do
  let myPos := [0, 0]
  let row :List String:= (List.replicate 5 ".")
  let board: List (List String) :=
    (List.replicate 5 row)

  let boardString:String := drawBoard board myPos[0] myPos[1]

  IO.println boardString

def shit  (x: Nat) : List String := ((List.replicate 5 ".").mapIdx (fun idx val => (if idx = x then "x" else val)))

def animationTest :IO Unit:=do
  let mut x := 0
  while true do
    IO.print "\r"
    IO.print (String.intercalate " " (shit x))
    (← IO.getStdout).flush
    IO.sleep 200
    -- todo it shouldnt be possible to end up outside of the board
    x:= (x+1) % 6

example : drawBoard [["."]] 0 0 = "x" := by rfl

example : drawBoard [[".", "."], [".", "."]] 1 1 = ". x\n. ." := by rfl
-- shit is it possible to show the expanded value, so it is easier to know what the calculation was?
-- #eval  drawBoard [[".", "."], [".", "."]] 1 1

-- todo this should not be possible
-- #eval drawBoard [[".", "."], [".", "."]] 2 0
-- todo this should not be possible
-- #eval drawBoard [[".", "."], ["."]] 0 0

-- todo we should refactor the x and y to be a {x,y} or a tuple with 2 elements or something

-- todo THIS CAN BE RUN WITH
-- cd /home/zikoat/dev/lean-tut/shit && lean --run ProofFarmer.lean

inductive Prog where
| skip : Prog
| seq : Prog → Prog → Prog
| while : Bool → Prog → Prog

def whileTrue : Prog :=
  Prog.while true Prog.skip

inductive Terminates : Prog → Type where
| skip : Terminates Prog.skip
| seq (p q : Prog) :
    Terminates p → Terminates q → Terminates (Prog.seq p q)
| while_done (body : Prog) : Terminates (Prog.while false body)
| while_step (body : Prog) :
    Terminates (Prog.seq body (Prog.while true body)) →
    Terminates (Prog.while true body)

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

#eval IO.println "test"

-- def main : IO Unit := do
--   sleepTest

class MonadConsole (m : Type -> Type) where
  print : String -> m Unit

def appLogic {m : Type -> Type } [Monad m] [MonadConsole m] : m Nat := do
  MonadConsole.print "hello"
  pure 42


instance : MonadConsole IO where
  print s := IO.println s



#check appLogic

instance : MonadConsole Id where
  print _ := ()

#eval (appLogic (m:=Id))
#eval (appLogic (m:=IO))

theorem appLogic_id_returns_42 : (appLogic (m:=Id)) = 42 := by
  rfl

abbrev MockM := StateM (List String)

instance : MonadConsole MockM where
  print s := modify (fun xs => xs ++ [s])

def runMock : MockM a -> (a × List String)
  | act => act.run []

#eval runMock (appLogic (m := MockM))
#check StateM

def main : IO Unit := do
  myMainProgram

#eval main
