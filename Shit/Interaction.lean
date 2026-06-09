import Shit.World

set_option autoImplicit false

/- World interaction, following the `PocInteraction` pattern (one low-level input
   primitive, identical in IO and tests; pure policy/decoders lifted out; structural
   termination so `rfl`/decidable tests stay decidable).

   Three layers:
   - Core (pure-over-monad): the `WorldEnv` effect record + generic ops on it.
   - Real:  `realEnv : WorldEnv IO` — the only untested code (terminal + file syscalls).
   - Test:  `testEnv : WorldEnv TestM` — a pure scripted interpreter; the Program the
            Challenges reason about.

   This file does NOT touch the running game (`ProofFarmer.myMainProgram`); migrating
   that loop to use `WorldEnv` is a separate later step. -/

-- ---------- the command protocol (high level) ----------

-- The unlocks, indexed so a new unlock adds a *value*, not a constructor (keeps
-- existing `rfl` proofs whose `match` covers `Action` intact).
inductive UnlockId where
  | while_ | speed1 | grass1 | expand1
deriving DecidableEq, Repr

def applyUnlock : UnlockId -> World -> World
  | .while_  => unlock_while
  | .speed1  => unlock_speed_1
  | .grass1  => unlock_grass_1
  | .expand1 => unlock_expand_1

-- A game action: the protocol "passed back and forth", generalizing the POC's `Cmd`.
-- Each action is a pure `World -> World` (see `Action.apply`), so a `List Action`
-- literally IS the pure Program.
inductive Action where
  | move (dir : Direction)
  | harvest
  | wait (ticks : Nat)
  | unlock (u : UnlockId)

-- Pure semantics — the heart of the Program. Reuses `World.lean`'s pure functions;
-- `harvest`/`wait` replicate only the pure World transition of their IO counterparts
-- (the `render`/`sleep` effects live in the driver, not here).
def Action.apply (a : Action) (w : World) : World :=
  match a with
  | .move dir => _root_.move dir w
  | .harvest  =>
    let yield := if w.unlocked_grass_1 then 2 else 1
    { w with hay := w.hay + yield, ticks := w.ticks + 200 }
  | .wait t   => { w with ticks := w.ticks + t }
  | .unlock u => applyUnlock u w

-- The pure Program: fold actions over the World. Structurally recursive on the list.
def run : List Action -> World -> World
  | [],      w => w
  | a :: as, w => run as (a.apply w)

-- ---------- the effect record ----------

structure WorldEnv (m : Type -> Type) where
  print : String -> m Unit
  sleep : UInt32 -> m Unit
  save  : World -> m Unit
  -- Read the save: `none` = no file yet; `some (.ok w)` = a valid World; `some (.error e)`
  -- = a file that failed to parse/validate. JSON parsing lives here on the untested edge;
  -- the recovery orchestration built on this is pure and decidable.
  readSave : m (Option (Except String World))
  -- Move the corrupt save aside (into `corrupted/`) so the next load starts fresh.
  archive : m Unit
  -- The single low-level input primitive, identical in shape for IO and tests:
  -- read at most one byte. `timeout = none` blocks; `some ds` waits ds deciseconds.
  readRaw : (timeout : Option Nat) -> m (Option UInt8)

-- ---------- pure decoders, lifted out of the IO adapter ----------

def decodeByte (b : UInt8) : Char :=
  Char.ofNat b.toNat

def sttyArgs : Option Nat -> List String
  | none    => ["-icanon", "-echo", "min", "1", "time", "0"]
  | some ds => ["-icanon", "-echo", "min", "0", "time", toString ds]

-- Loading is a pipeline of three boundaries, each stricter than the last:
--   String  --parseJson-->  Json  --jsonToWorld-->  World (validated)
-- Only the first (the string parser) is irreducible under `rfl`; the `Json -> World`
-- step (field extraction + the out-of-bounds rejection) DOES reduce, so the validation
-- that catches a stale save is decidable and unit-tested below.
def parseJson (s : String) : Except String Lean.Json :=
  Lean.Json.parse s

def jsonToWorld (j : Lean.Json) : Except String World :=
  Lean.fromJson? j

def parseWorld (s : String) : Except String World :=
  parseJson s >>= jsonToWorld

-- The recovery choice offered when a save is corrupt.
inductive Recovery where
  | delete | retry
deriving DecidableEq, Repr

def recoveryChoice : Char -> Option Recovery
  | 'd' => some .delete
  | 'r' => some .retry
  | _   => none

def corruptPrompt (e : String) : String :=
  s!"save file is corrupt ({e}).\n" ++
  "edit world.json by hand and press 'r' to retry, or press 'd' to delete it " ++
  "(moved to corrupted/) and start over."

-- The keymap: which keypress means which game action. Pure, so tested for free.
-- Unknown keys decode to `none` (ignored by the driver).
def keyToAction : Char -> Option Action
  | 'w' => some (.move .north)
  | 's' => some (.move .south)
  | 'a' => some (.move .west)
  | 'd' => some (.move .east)
  | 'h' => some .harvest
  | '1' => some (.unlock .while_)
  | '2' => some (.unlock .speed1)
  | '3' => some (.unlock .grass1)
  | '4' => some (.unlock .expand1)
  | _   => none

-- ---------- generic ops, built on the record (so they are testable too) ----------

def readKey {m} [Monad m] (env : WorldEnv m) : m Char := do
  let b <- env.readRaw none
  pure ((b.map decodeByte).getD ' ')

-- The interactive driver: read a key, decode it to an action, apply, persist, repeat.
-- Unknown keys are ignored (no state change). `budget` bounds the loop so this stays
-- structurally terminating, which keeps the `rfl` tests decidable. A `none` read
-- (real EOF / poll timeout) ends the loop cleanly.
def drive {m} [Monad m] (env : WorldEnv m) (w : World) : Nat -> m World
  | 0         => pure w
  | budget + 1 => do
    let b <- env.readRaw none
    match b with
    | none      => pure w
    | some byte =>
      match keyToAction (decodeByte byte) with
      | some act =>
        let w' := act.apply w
        env.save w'
        drive env w' budget
      | none     => drive env w budget

-- Load the save, recovering from a corrupt one by asking the user to retry (after a
-- hand-edit) or delete (archive + start fresh).
mutual
def loadWithRecovery {m} [Monad m] (env : WorldEnv m) : Nat -> m World
  | 0          => pure {}
  | budget + 1 => do
    match <- env.readSave with
    | none           => pure {}
    | some (.ok w)   => pure w
    | some (.error e) => do
      env.print (corruptPrompt e)
      recover env budget
-- The corrupt-save prompt is up; wait for a recovery key. Stray keys are ignored
-- (no reprint, no re-read), like the POC's `waitForA`. `budget` bounds the wait.
def recover {m} [Monad m] (env : WorldEnv m) : Nat -> m World
  | 0          => pure {}
  | budget + 1 => do
    let key <- readKey env
    match recoveryChoice key with
    | some .delete => do env.archive; pure {}
    | some .retry  => loadWithRecovery env budget
    | none         => recover env budget
end

-- ---------- real ----------

def stty (args : List String) : IO Unit := do
  let line := "stty " ++ String.intercalate " " args ++ " </dev/tty"
  let _ <- IO.Process.run {cmd := "sh", args := #["-c", line] }

def sttyState : IO String := do
  let out <- IO.Process.run {cmd := "sh", args := #["-c", "stty -g </dev/tty"] }
  pure (String.ofList (out.toList.filter (· != '\n')))

-- The ONLY untested code: irreducible terminal + file syscalls.
def realEnv : WorldEnv IO where
  print := IO.println
  sleep ms := IO.sleep ms
  save  := saveWorld
  readSave := do
    if <- default_world_file.pathExists then
      let s <- IO.FS.readFile default_world_file
      pure (some (parseWorld s))
    else pure none
  archive := do
    IO.FS.createDirAll "corrupted"
    let t <- IO.monoMsNow
    IO.FS.rename default_world_file (System.FilePath.mk s!"corrupted/world-{t}.json")
  readRaw timeout := do
    let saved <- sttyState
    stty (sttyArgs timeout)
    let bytes <- (<- IO.getStdin).read 1
    stty [saved]
    pure bytes.toList.head?

-- ---------- test setup ----------

-- Low-level scripted input, mirroring what `readRaw` sees on the real terminal.
inductive Cmd where
  | press (c : Char)   -- a byte sitting in the buffer, available now
  | gap (ds : Nat)     -- ds deciseconds of silence
  | stop               -- test-only: freeze execution at the next read

structure TestState where
  script : List Cmd                              -- keypress script for readRaw
  saves : List (Option (Except String World)) := []  -- successive readSave results
  world : World := {}
  log : List String := []
  archived : Nat := 0                            -- how many times `archive` was called

abbrev TestM :=
  ExceptT Unit (StateM TestState)

def byteOf (c : Char) : UInt8 :=
  UInt8.ofNat c.toNat

-- Pure interpreter of one read against the script (identical to the POC).
def stepRead : Option Nat -> List Cmd -> Except Unit (Option UInt8) × List Cmd
  | _,           Cmd.stop :: rest    => (.error (), rest)
  | none,        []                  => (.error (), [])
  | none,        Cmd.gap _ :: rest   => stepRead none rest
  | none,        Cmd.press c :: rest => (.ok (some (byteOf c)), rest)
  | some _,      []                  => (.ok none, [])
  | some budget, Cmd.gap d :: rest   =>
      if budget <= d then (.ok none, Cmd.gap (d - budget) :: rest)
      else stepRead (some (budget - d)) rest
  | some _,      Cmd.press c :: rest => (.ok (some (byteOf c)), rest)

def testEnv : WorldEnv TestM where
  print s := modify fun st => { st with log := st.log ++ [s] }
  sleep _ := pure ()
  save w  := modify fun st => { st with world := w }
  readSave := do
    let st <- get
    match st.saves with
    | []        => pure none
    | s :: rest => do set { st with saves := rest }; pure s
  archive := modify fun st => { st with archived := st.archived + 1 }
  readRaw timeout := do
    let st <- get
    let (res, rest) := stepRead timeout st.script
    set { st with script := rest }
    match res with
    | .ok b => pure b
    | .error _ => throw ()

-- Drive a scripted keypress sequence and read back the persisted World.
-- `save`-per-step means the World survives even when the script freezes at `stop`.
def driveTest (script : List Cmd) (w0 : World := {}) : World :=
  (((drive testEnv w0 100).run.run { script, world := w0 }).snd).world

-- High-level input helpers: each expands to one or more low-level Cmds.
def key (c : Char) : List Cmd := [.press c]
def stopHere : List Cmd := [.stop]

-- Run `loadWithRecovery` against scripted save-reads + keypresses; return the
-- resulting World (fresh `{}` if the script froze) and the final TestState.
def loadTest (saves : List (Option (Except String World))) (keys : List Cmd) :
    World × TestState :=
  match (loadWithRecovery testEnv 100).run.run { script := keys, saves } with
  | (res, st) => (res.toOption.getD {}, st)

-- ---------- tests ----------

-- Pure decoders, tested directly.
example : decodeByte 97 = 'a' := by rfl
example : keyToAction 'h' = some .harvest := by rfl
example : keyToAction 'w' = some (.move .north) := by rfl
example : keyToAction 'z' = none := by rfl
example : sttyArgs none = ["-icanon", "-echo", "min", "1", "time", "0"] := by rfl

-- The pure Program: a `List Action` folded over a World.
example : (Action.apply .harvest {}).hay = 1 := by rfl
example : (Action.apply .harvest {}).ticks = 200 := by rfl
example : (run [.harvest, .harvest] {}).hay = 2 := by rfl
example : (run [.harvest, .harvest, .wait 0] {}).ticks = 400 := by rfl

-- Unlock via the protocol: 30 hay then unlock expand_1 flips the bit and spends hay.
example :
    let w := run [.wait 0] { hay := 30 }
    (Action.apply (.unlock .expand1) w).unlocked_expand_1 = true := by rfl

-- Driving the SAME World through scripted keypresses (low-level input layer).
-- 'h' 'h' harvest twice; the 'stop' freezes the read but the saved World persists.
example : (driveTest (key 'h' ++ key 'h' ++ stopHere)).hay = 2 := by rfl

-- An unknown key is ignored (no state change), a following 'h' still harvests.
example : (driveTest (key 'z' ++ key 'h' ++ stopHere)).hay = 1 := by rfl

-- No input freezes immediately at the first (blocking) read; World untouched.
example : (driveTest []).hay = 0 := by rfl

-- ---------- loading / recovery ----------

-- Tracer: a corrupt save, user presses 'd' -> the corrupt file is archived...
example : (loadTest [some (.error "out of bounds")] (key 'd')).2.archived = 1 := by rfl
-- ...and the game starts fresh from the default World.
example : (loadTest [some (.error "out of bounds")] (key 'd')).1.hay = 0 := by rfl

-- Corrupt save, user hand-edits the file and presses 'r' -> the now-valid World loads.
example :
    (loadTest [some (.error "bad"), some (.ok { hay := 7 })] (key 'r')).1.hay = 7 := by rfl

-- A stray key while the corrupt-save prompt is up is ignored; a following 'd' still archives.
example :
    (loadTest [some (.error "bad")] (key 'x' ++ key 'd')).2.archived = 1 := by rfl

-- No save file -> start fresh from the default World, with no prompt and no archive.
example : (loadTest [none] []).1.hay = 0 := by rfl
example : (loadTest [none] []).2.log = [] := by rfl
example : (loadTest [none] []).2.archived = 0 := by rfl

-- A valid save loads directly, with no prompt and no archive.
example : (loadTest [some (.ok { hay := 42 })] []).1.hay = 42 := by rfl
example : (loadTest [some (.ok { hay := 42 })] []).2.log = [] := by rfl

-- The migrated farmer bug, at the decidable `Json -> World` boundary. An expanded
-- board (`world_size_for true = {x:=1, y:=3}`) requires `y < 3`, so a save with
-- `myPos.y = 3` is rejected; the same board with `y = 2` loads. Both reduce under rfl.
def jsonOf (y : Nat) (expand : Bool) : Lean.Json := Lean.Json.mkObj [
  ("myPos", Lean.toJson ({ y } : Pos)),
  ("ticks", Lean.toJson (0 : Nat)),
  ("hay", Lean.toJson (0 : Nat)),
  ("unlocked_while", Lean.toJson false),
  ("unlocked_speed_1", Lean.toJson false),
  ("unlocked_grass_1", Lean.toJson false),
  ("unlocked_expand_1", Lean.toJson expand)]

example : (jsonToWorld (jsonOf 3 true)).toOption.isNone = true := by rfl
example : (jsonToWorld (jsonOf 2 true)).toOption.isSome = true := by rfl
