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

-- moveEast removed: use `move .east` (defined below). The +200 tick cost
-- can be added at the call site if needed.

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


def unlock_expand_1 (w : World) : World :=
  if h : w.hay >= 30 && !w.unlocked_expand_1 then
    { w with
      unlocked_expand_1 := true
      hay := w.hay - 30
      myPos_valid := by
        -- w.unlocked_expand_1 was false, so old size = (1,1).
        -- That forces myPos = (0,0). Both coords are < new size (1, 3).
        have hExpand : w.unlocked_expand_1 = false := by
          simp at h; exact h.2
        have hOld := w.myPos_valid
        rw [hExpand] at hOld
        simp [world_size_for] at hOld
        simp [world_size_for, hOld]
    }
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


-- JSON serialization: skip the proof field on save, validate on load.
instance : Lean.ToJson World where
  toJson w := Lean.Json.mkObj [
    ("myPos", Lean.toJson w.myPos),
    ("ticks", Lean.toJson w.ticks),
    ("hay", Lean.toJson w.hay),
    ("unlocked_while", Lean.toJson w.unlocked_while),
    ("unlocked_speed_1", Lean.toJson w.unlocked_speed_1),
    ("unlocked_grass_1", Lean.toJson w.unlocked_grass_1),
    ("unlocked_expand_1", Lean.toJson w.unlocked_expand_1)
  ]

instance : Lean.FromJson World where
  fromJson? j := do
    let myPos ← j.getObjValAs? Pos "myPos"
    let ticks ← j.getObjValAs? Nat "ticks"
    let hay ← j.getObjValAs? Nat "hay"
    let unlocked_while ← j.getObjValAs? Bool "unlocked_while"
    let unlocked_speed_1 ← j.getObjValAs? Bool "unlocked_speed_1"
    let unlocked_grass_1 ← j.getObjValAs? Bool "unlocked_grass_1"
    let unlocked_expand_1 ← j.getObjValAs? Bool "unlocked_expand_1"
    if h : myPos.x < (world_size_for unlocked_expand_1).x ∧
           myPos.y < (world_size_for unlocked_expand_1).y then
      pure { myPos, ticks, hay, unlocked_while, unlocked_speed_1,
             unlocked_grass_1, unlocked_expand_1, myPos_valid := h }
    else
      .error "loaded position out of bounds"

-- BEq, ignoring proof field (proof irrelevance).
instance : BEq World where
  beq a b :=
    a.myPos == b.myPos
    && a.ticks == b.ticks
    && a.hay == b.hay
    && a.unlocked_while == b.unlocked_while
    && a.unlocked_speed_1 == b.unlocked_speed_1
    && a.unlocked_grass_1 == b.unlocked_grass_1
    && a.unlocked_expand_1 == b.unlocked_expand_1

-- Repr for #eval.
instance : Repr World where
  reprPrec w _ :=
    s!"\{ myPos := {repr w.myPos}, ticks := {w.ticks}, hay := {w.hay}, "
    ++ s!"unlocked_while := {w.unlocked_while}, unlocked_speed_1 := {w.unlocked_speed_1}, "
    ++ s!"unlocked_grass_1 := {w.unlocked_grass_1}, unlocked_expand_1 := {w.unlocked_expand_1} }"

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


def world_size (w : World) : Pos := world_size_for w.unlocked_expand_1

def move (dir : Direction) (w : World) : World :=
  match dir with
  | .north =>
    { w with
      myPos := { x := w.myPos.x, y := (w.myPos.y + (world_size w).y + 1) % (world_size w).y }
      myPos_valid := by
        refine ⟨w.myPos_valid.1, ?_⟩
        show _ % (world_size_for w.unlocked_expand_1).y < _
        exact Nat.mod_lt _ (world_size_for_y_pos _)
    }
  | .east =>
    { w with
      myPos := { x := (w.myPos.x + (world_size w).x + 1) % (world_size w).x, y := w.myPos.y }
      myPos_valid := by
        refine ⟨?_, w.myPos_valid.2⟩
        show _ % (world_size_for w.unlocked_expand_1).x < _
        exact Nat.mod_lt _ (world_size_for_x_pos _)
    }
  | .south =>
    { w with
      myPos := { x := w.myPos.x, y := (w.myPos.y + (world_size w).y - 1) % (world_size w).y }
      myPos_valid := by
        refine ⟨w.myPos_valid.1, ?_⟩
        show _ % (world_size_for w.unlocked_expand_1).y < _
        exact Nat.mod_lt _ (world_size_for_y_pos _)
    }
  | .west =>
    { w with
      myPos := { x := (w.myPos.x + (world_size w).x - 1) % (world_size w).x, y := w.myPos.y }
      myPos_valid := by
        refine ⟨?_, w.myPos_valid.2⟩
        show _ % (world_size_for w.unlocked_expand_1).x < _
        exact Nat.mod_lt _ (world_size_for_x_pos _)
    }
