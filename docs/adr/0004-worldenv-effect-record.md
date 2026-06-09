# Interaction through a `WorldEnv` effect record + pure World transitions

**Decided.** Game interaction goes through an effect record — a `structure` of effectful
operations over a monad `m` (`WorldEnv m`, in `Shit/Interaction.lean`) — so one core logic
runs with a real `IO` instance and a pure test instance. Game Actions have pure semantics
on the World (`Action.apply : Action → World → World`), and loading is layered
(`file → string → JSON → validated World`) so a caller can enter at whatever granularity it
needs.

**Why — provability.** The point is making the code easy to write proofs (Challenges)
about. Challenges can be created about *any* code, but pure World transitions are the
easiest to reason about, so Actions have pure semantics. Separating the effectful
operations into the record lets a proof or test work at the granularity it needs — the
whole stack, in-memory strings only, or a directly-provided valid World — and lets a
Challenge leave out the effects it doesn't need.

**Example property.** Save/load symmetry (saving then loading round-trips, assuming no
tampering) is a property of the real save/serialization path — the pure/test env starts
from an already-valid or empty World, so it never exercises the round-trip — yet it can
still be posed as a Challenge. (Tracked in TODOS.)

**Not yet fixed (changeable).**
- The exact `WorldEnv` method list — currently `print`, `sleep`, `save`, `readSave`,
  `archive`, `readRaw` — is provisional, expected to change as the game grows.
- A Program is modelled as a `List Action` folded by `run` as a first approximation; a real
  Program derives the next Action from the script as it runs.
- Whether an effect-as-data / TEA design is ever warranted (set aside for now).
