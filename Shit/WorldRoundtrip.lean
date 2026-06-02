import Shit.World

/- Roundtrip check for `World` JSON (de)serialization.

    Lives in its own module — NOT in `Shit.Proofs` — on purpose: this `#eval`
    writes `test_world.json` at elaboration time. `Challenge.lean` imports
    `Shit.Proofs`, so the comparator builds that module inside a landrun FS
    sandbox; a write there fails with "permission denied". Keeping the side
    effect here (imported only by the library root, never by `Shit.Proofs`)
    keeps the trusted compile surface side-effect-free while the normal
    `lake build Shit` still runs the roundtrip. -/
#eval show IO Unit from do
  let w_0 : World := { ticks := 400, unlocked_expand_1 := true, myPos := {y:=2} }
  saveWorld w_0 "test_world.json"
  let w_1 <- loadWorld "test_world.json"
  unless w_0 == w_1 do
    throw (IO.userError s!"roundtrip mismatch:\n  before: {repr w_0}\n  after:{repr w_1}")
