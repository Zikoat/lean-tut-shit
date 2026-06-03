# ProofFarmer

A Lean reimplementation of the game *The Farmer Was Replaced*, used to study how formal
verification scales with software size. It contains a verification pipeline that lets an
untrusted AI submit Lean proofs for open theorems and merges them only if they genuinely
prove the stated theorem.

## Language

### Game

**ProofFarmer**:
This project — a Lean reimplementation of the programming game *The Farmer Was Replaced*.
_Avoid_: the farmer, the game, the sim.

**World**:
The game state the agent acts on: the grid, the agent position (`myPos`), the tick count,
and which Unlocks are owned, carrying an in-bounds invariant.
_Avoid_: board, grid, state.

**Program**:
The agent code that executes actions in the World. Has two variants: an **IO Program**
(actions take real time, e.g. ~200 ms per move) and a **pure Program** (no `IO`, easier
to reason about and prove). Challenges reason about the pure Program, precisely because
`IO` is hard to reason about.
_Avoid_: agent, script, bot, solver.

**Unlock**:
A capability bought (with hay/resources) to progress through the game; the full set and
costs are a fixed external spec from the game wiki. Unlocks form a tree; the last Unlock
is **leaderboard**, and reaching it then terminating is the project's end goal (the
implementation will likely stop well short).
_Avoid_: upgrade, level, feature, achievement.

**Sorry-based programming**:
The working paradigm of stubbing theorems with `sorry` and discharging them incrementally
as the code stabilizes, rather than proving everything up front.
_Avoid_: stub-driven, proof-later.

### Proof verification pipeline

**Proposition**:
The bare statement type of a Challenge, defined in `Shit/Proofs.lean` alongside the
project's other proofs (so Challenges can double as ProofFarmer tests). E.g.
`def Contrapositive (p q : Prop) : Prop := (p → q) → (¬q → ¬p)`.
_Avoid_: statement, type, goal

**Challenge**:
A trusted, read-only `Challenge.lean` that imports a Proposition `P` and states a
`sorry`-stubbed goal the Solution must resolve. Usually the goal is a decision instance,
`def <name> : Decidable P := sorry`, so the Solution supplies `isTrue h` (a proof of `P`)
or `isFalse h` (a proof of `¬P`). The statement stays the same either way, so the
untrusted agent can prove *or* disprove `P` without editing it. A few Propositions are
not decidable (e.g. universally-quantified ones like `Contrapositive`); those stay a
plain `theorem … := sorry` and admit only a proof.
_Avoid_: problem, task

**Challenge state**:
Where a Challenge stands, by colour: **Open** ("yellow") — still `sorry`; **Proven**
("green") — the accepted `Decidable P` instance is `isTrue` (`P` holds); **Disproven**
("red") — it is `isFalse` (`¬P` holds). A Disproven Challenge usually signals the
underlying code or theorems need a follow-up change, whereas Proven needs none. A
Challenge reverts to Open when its accepted Solution is deleted — because a code change
invalidated the proof, or a false proof was found and the pipeline hardened — after which
the agent re-solves.
_Avoid_: status, verdict, colour.

**Solution**:
The untrusted AI's single file `Solution.lean` that resolves the Challenge: for a
`Decidable P` goal, the decision instance (`isTrue` with a proof of `P`, or `isFalse`
with a proof of `¬P`); for a plain theorem goal, a proof of it.
May import Mathlib (cslib is
intended but not yet a `lakefile.toml` dependency). The AI owns nothing else; there is
no bridge and no reference proof.
_Avoid_: submission, answer, attempt

**Workspace**:
A per-Challenge directory holding that Challenge's `Challenge.lean`, `Solution.lean`,
and comparator `config.json`. One dir per Challenge so Solutions never collide.
_Avoid_: problem dir, folder

**Comparator**:
The trusted verifier (`leanprover/comparator`) that judges a Solution against a
Challenge: confirms the statement wasn't redefined, axioms are within the permit
list, no `sorry`, and the proof passes the Lean kernel.
_Avoid_: checker, judge, validator

**Permit list**:
The explicit set of axioms a Solution is allowed to depend on. Anything outside it
(notably `sorryAx`) fails verification. Default, shared by all Challenges: the three
standard Lean axioms `propext`, `Quot.sound`, `Classical.choice`.
_Avoid_: allowlist, whitelist

**Trusted side / Untrusted side**:
Trusted = human+AI who own the Challenge, the Permit list, and the CI config.
Untrusted = the AI that may only produce a Solution and nothing else.
_Avoid_: ours/theirs, internal/external

**Trusted import surface**:
The libraries a Challenge/Solution may import, all of which are therefore trusted:
core Lean and Mathlib (cslib is intended but not yet wired into `lakefile.toml`).
Expanding this set is a deliberate trust-surface decision (comparator trusts the
Challenge's imports).
_Avoid_: dependencies, allowed libs
