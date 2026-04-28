import Lean


structure Pos where
  x : Nat := 0
  y : Nat := 0
deriving Repr, Lean.ToJson, Lean.FromJson, BEq

structure World where
  myPos: Pos := {}
  ticks: Nat := 0
  hay: Nat := 0
  while_unlocked: Bool := false
deriving Repr, Lean.ToJson, Lean.FromJson, BEq

def base_ticks_per_second := 400

def moveEast (w:World) : World :=
  { w with
    myPos := {w.myPos with x:= w.myPos.x+1}
    ticks := w.ticks + 200}

def harvest (w:World):World :=
   { w with
    ticks := w.ticks + 200
    hay := w.hay + 1}


def do_a_flip (w:World):World :=
  {w with
    ticks := w.ticks + 1 * base_ticks_per_second}

def unlock_while (w:World):World :=
  if w.hay >= 5 then
    { w with
      while_unlocked := true}
  else w

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
