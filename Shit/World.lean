import Lean

structure Pos where
  x : Nat := 0
  y : Nat := 0
deriving Repr, Lean.ToJson, Lean.FromJson, BEq

def world_size_for (unlocked_expand_1 : Bool) : Pos :=
  if unlocked_expand_1 then {x:=1, y:=3} else {x:=1, y:=1}

theorem world_size_for_x_pos (b : Bool) : (world_size_for b).x > 0 := by
  cases b <;> simp [world_size_for]

theorem world_size_for_y_pos (b : Bool) : (world_size_for b).y > 0 := by
  cases b <;> simp [world_size_for]

structure World where
  myPos: Pos := {}
  ticks: Nat := 0
  hay: Nat := 0
  unlocked_while: Bool := false
  unlocked_speed_1 : Bool := false
  unlocked_grass_1: Bool := false
  unlocked_expand_1: Bool := false
  myPos_valid :
    myPos.x < (world_size_for unlocked_expand_1).x ∧
    myPos.y < (world_size_for unlocked_expand_1).y
    := by simp [world_size_for]

def base_ticks_per_second := 400

def moveEast (w:World) : World :=
  { w with
    myPos := {w.myPos with x:= w.myPos.x+1}
    ticks := w.ticks + 200}

def wait_ticks
    (ticks: Nat)
    (w : World)
    (sleep :( UInt32) -> BaseIO Unit)
    (render : World -> IO Unit): IO World := do
  let w_next := {w with ticks := w.ticks + ticks }
  render w_next
  let ms_base := ticks * 1000 / base_ticks_per_second
  let ms := (if w.unlocked_speed_1 then ms_base * 2 / 3 else ms_base)
  sleep ms.toUInt32
  pure w_next

def harvest (w:World) (sleep :( UInt32) -> BaseIO Unit)  (render : World -> IO Unit):IO World :=
  let yield := if w.unlocked_grass_1 then 2 else 1
  wait_ticks (200) ({ w with
    hay := w.hay + yield}) sleep render

def do_a_flip (w:World):World :=
  {w with
    ticks := w.ticks + 1 * base_ticks_per_second}

-- this is the first unlock, but it actually doesnt do anything, because while is always unlocked
def unlock_while (w:World):World :=
  if w.hay >= 5 && !w.unlocked_while then
    { w with
      unlocked_while := true
      hay := w.hay - 5}
  else w

def unlock_speed_1(w:World):World :=
  if w.hay >= 20 && !w.unlocked_speed_1 then
    {w with
      unlocked_speed_1 := true
      hay := w.hay - 20}
  else w

def unlock_grass_1(w:World):World:=
  if w.hay >= 300 && !w.unlocked_grass_1 then
    {w with
      unlocked_grass_1 := true
      hay := w.hay - 300}
  else w


def unlock_expand_1(w:World):World:=
  if w.hay >= 30 && !w.unlocked_expand_1 then
    {w with
      unlocked_expand_1 := true
      hay := w.hay - 30}
  else w

-- 1x1
-- {Hay: 30},1×3
-- {Wood: 20},3x3
-- {Wood: 30, Carrot: 20},4x4
-- {Wood: 100, Carrot: 50},
-- {Pumpkin: 1000},
-- {Pumpkin: 8000},
-- {Pumpkin: 64000},
-- {Pumpkin: 512000},
-- {Pumpkin: 4100000}


def default_world_file:System.FilePath := "world.json"

def loadWorld (path: System.FilePath:= default_world_file) : IO World := do
  if <- path.pathExists then
    let s <- IO.FS.readFile path
    match Lean.Json.parse s >>= Lean.fromJson? (α := World) with
    | .ok w => pure w
    | .error e => throw (IO.userError s!"loadWorld: {e}")
  else pure {}

def saveWorld (w:World) (path: System.FilePath:=default_world_file) : IO Unit :=
  IO.FS.writeFile path (Lean.toJson w).pretty

inductive Direction where
  | north
  | east
  | south
  | west


def world_size (w:World): Pos :=
  if w.unlocked_expand_1
  then {x:=1,y:=3}
  else {x:=1,y:=1}

def move(dir:Direction)(w:World):World :=
  match dir with
  |.north =>{w with myPos:={w.myPos with y:=(w.myPos.y+(world_size w).y+1)% (world_size w).y}}
  |.east => {w with myPos := {w.myPos with x:=(w.myPos.x+(world_size w).x+1)% (world_size w).x}}
  |.south => {w with myPos := {w.myPos with y:=(w.myPos.y+(world_size w).y-1)% (world_size w).y}}
  |.west => {w with myPos := {w.myPos with x:=(w.myPos.x+(world_size w).x-1)% (world_size w).x} }
