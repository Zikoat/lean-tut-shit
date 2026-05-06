import Init.Control.State
import Shit.World

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

def drawBoard (board: List (List String)) (pos: Pos) : String :=
  String.intercalate "\n" ((
      board.mapIdx fun y' row =>
        if pos.y < board.length ∧ y' = (board.length - pos.y - 1) then
          row.mapIdx (setXIfCoordinateIsSame pos.x)
        else
          row
    ).map (String.intercalate " "))

def Carrot_emoji := "🥕"
def Fertilizer_emoji:= "💩"
def Gold_emoji:= "🪙"
def Hay_emoji:= "🌾"
def Power_emoji:= "⚡"
def Pumpkin_emoji:= "🎃"
def Water_emoji:= "💧"
def Wood_emoji:= "🪵"
def Cactus_emoji:= "🌵"
def Bones_emoji:= "🦴"
def Tick_emoji:="🕰️"


def render_terminal (w: World) : IO Unit := do
  let world_size_calc := world_size w
  let render_height := world_size_calc.y + 2
  IO.print s!"\x1b[{render_height}A\x1b[J"
  let row :List String:= (List.replicate (world_size w).x ".")
  let board: List (List String) :=
    (List.replicate (world_size w).y row)

  let boardString:String := drawBoard board w.myPos
  -- IO.println ""
  IO.println boardString
  IO.println s!"{w.ticks} {Tick_emoji} | {w.hay} {Hay_emoji}"
  IO.println s!"unlocks: {
  if w.unlocked_while then "while" else ""} {
  if w.unlocked_speed_1 then "speed_1" else ""} {
  if w.unlocked_grass_1 then "grass_1" else ""} {
  if w.unlocked_expand_1 then "expand_1" else ""}"
  saveWorld w

def render_noop (_w: World) : IO Unit := do
  pure ()

def myMainProgram (sleep:UInt32 -> BaseIO Unit)  (render : World -> IO Unit): IO World := do
  IO.print "\n\n\n\n\n\n"
  let mut w <- loadWorld


  -- world := moveEast (moveEast world)
  w <- harvest w sleep render
  w <- wait_ticks (1 * base_ticks_per_second) w sleep render
  w <- harvest w sleep render
  w <- harvest w sleep render
  w <- harvest w sleep render
  w <- harvest w sleep render

  w := move .north w --sleep render

  while True do
    w <- harvest w sleep render
    w := unlock_while w
    w := unlock_grass_1 w
    w := unlock_speed_1 w
    w := unlock_expand_1 w

  render w
  pure w

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

example : drawBoard [["."]] {} = "x" := by rfl

example : drawBoard [[".", "."], [".", "."]] {x:=1, y:=1} = ". x\n. ." := by rfl
-- shit is it possible to show the expanded value, so it is easier to know what the calculation was?
-- #eval  drawBoard [[".", "."], [".", "."]] 1 1

-- todo this should not be possible
-- #eval drawBoard [[".", "."], [".", "."]] 2 0
-- todo this should not be possible
-- #eval drawBoard [[".", "."], ["."]] 0 0

-- todo we should refactor the x and y to be a {x,y} or a tuple with 2 elements or something

-- todo THIS CAN BE RUN WITH
-- cd /home/zikoat/dev/lean-tut/shit && lean --run ProofFarmer.lean

class MonadConsole (m : Type -> Type) where
  print : String -> m Unit

def appLogic {m : Type -> Type } [Monad m] [MonadConsole m] : m Nat := do
  MonadConsole.print "hello"
  pure 42


instance : MonadConsole IO where
  print s := IO.println s



-- #check appLogic

instance : MonadConsole Id where
  print _ := ()

-- #eval (appLogic (m:=Id))
-- #eval (appLogic (m:=IO))

theorem appLogic_id_returns_42 : (appLogic (m:=Id)) = 42 := by
  rfl

abbrev MockM := StateM (List String)

instance : MonadConsole MockM where
  print s := modify (fun xs => xs ++ [s])

def runMock : MockM a -> (a × List String)
  | act => act.run []

-- #eval runMock (appLogic (m := MockM))
-- #check StateM



def sleep_wait (ms : UInt32) : BaseIO Unit
 := IO.sleep ms

def sleep_noop (_ms : UInt32) : BaseIO Unit
 := pure ()

def main : IO Unit := do
  _ <- myMainProgram sleep_wait render_terminal

-- #eval myMainProgram sleep_noop render_noop
