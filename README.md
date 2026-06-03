# shit — ProofFarmer

A work-in-progress Lean reimplementation of the programming game *The Farmer Was
Replaced* ([mechanics wiki](https://thefarmerwasreplaced.wiki.gg/)). The game has an
**unlock tree**; buying unlocks adds features and challenges, and reaching the **last
unlock** (`leaderboard`) is the end goal. The full unlock set and costs are a fixed spec
([Unlocks Data](https://thefarmerwasreplaced.wiki.gg/wiki/Unlocks_Data)); what each
unlock changes in the code varies.

The end-game theorem has the form: *"provide a Program that unlocks the last unlock and
then terminates in finite time, and prove that it does."* We expect to build a few
sub-proofs for intermediate unlocks so the whole thing can be proved in pieces rather
than all at once.

**Stretch goal:** search the Program space for one that reaches the last unlock in the
*fewest ticks* — a hard optimization problem, well beyond the base end-game theorem.

### Why this project exists

This is my first Lean project, so **a lot of scratch is expected**, and we will most
likely implement only the first few unlocks before halting. Fully proving the program is
*not* the point — the API and design are still being figured out as we go.

The real goal is to learn **how formal verification scales with software size and
complexity**, and how a **"sorry-based programming"** paradigm — stubbing theorems with
`sorry` and discharging them incrementally as the code stabilizes — can be used most
effectively.

The trusted codebase is the **World**, the **Program** that executes actions in it, and
the authoring of **Challenges** (proof obligations about world invariants and other
properties). The untrusted part is the creation of **Solutions** (the proofs) — see
[CONTEXT.md](./CONTEXT.md) for the verification pipeline and [docs/adr/](./docs/adr/) for
decisions.

Implementation notes:
- Actions take real time (e.g. ~200 ms per `move`), so the Program will exist in two
  variants: one threaded with `IO` (can wait, runs for real) and a pure one (no `IO`,
  easier to reason about and prove). Accumulated `ticks` are the clock for the `IO`
  ("displayed"/game) version — it waits out the ticks and renders; in the pure version
  `ticks` is just a counter.
- A VS Code widget to display the current board state is planned.

### Research questions

The questions this project is meant to answer:

- If a theorem's proof exists and the underlying code changes, how large/devastating are
  the resulting changes to the proof?
- How often does a code change invalidate a proof?
- How fast is an agent at proving a theorem?
- Can an agent reuse past proofs to help prove new theorems?
- Can we make the proving process more efficient?
- Can we use `plausible` to quickly refute hard or false theorems?
- Can we use `Decidable` to get both positive and negative proofs?
- How much work is it to harden the pull-request flow for auto-merge?
- How do we set up a fully automatic theorem-proving software agent?
- How accurate is such an agent at proving theorems?
- If proving becomes fully automatic, do we lose the ability to extract necessary,
  correct, desired, or creative changes to the world/program/theorems — because we only
  ever end up with a true/false verdict?

## Development

### Requirements

- Lean toolchain `leanprover/lean4:v4.29.0-rc1` (pinned in `lean-toolchain`, installed automatically by [`elan`](https://github.com/leanprover/elan)).
- [`mathlib`](https://github.com/leanprover-community/mathlib4) is a dependency (declared in `lakefile.toml`).

Built with [Lake](https://github.com/leanprover/lean4/tree/master/src/lake), Lean's build tool. There is no Makefile.

### Common commands

| Task | Command |
| --- | --- |
| Build **and proof-check** everything | `lake build` |
| Build just the executables | `lake build shit farmer` |
| Run the tutorial exe (`Main.lean`) | `lake exe shit` |
| Run the farming simulation (`ProofFarmer.lean`) | `lake exe farmer` |
| Style lint (docstrings, unused args) | `lake lint` |
| Re-download prebuilt mathlib (if cache lost) | `lake exe cache get` |
| Update dependency revisions | `lake update` |

> **Proof-checking is `lake build`.** Lean elaborates and verifies every theorem/`example` during the build, so a green build means the proofs check. `lake lint` only reports style issues and is non-fatal.

### Running `farmer` & resetting the game

`farmer` loads and **saves game state to `world.json`** (which is git-ignored) on every run via `saveWorld`. The position must stay in bounds — `world_size_for` is `1×3` once `unlocked_expand_1` is bought, otherwise `1×1` — so a saved `myPos` outside that range makes startup fail with:

```
uncaught exception: loadWorld: loaded position out of bounds
```

To **reset / restart** the game:

```bash
rm world.json              # next run starts from the default valid state (pos 0,0)
# or seed it from the tracked fixture:
cp test_world.json world.json
```

`farmer` then runs a long simulation loop and re-saves to `world.json` as it goes; stop it with Ctrl-C.

### Project layout

```
Main.lean                       # `shit` exe — Lean tutorial scratchpad
ProofFarmer.lean                # `farmer` exe entry point (currently learning scratch)
Shit.lean                       # library root
Shit/World.lean                 # World state, Pos, bounds invariant (myPos_valid), move/unlock, JSON load/save
Shit/Proofs.lean                # proofs about the world (bounds, move wrap-around) + the Contrapositive Proposition
Shit/WorldRoundtrip.lean        # `#eval` round-trip check for World JSON (kept out of Proofs.lean — see comparator note below)
Shit/Basic.lean                 # `hello` helper
Shit/Scratch.lean               # Lean-learning scratch
Shit/Absurdity_test.lean        # Lean-learning scratch
Shit/Challenges/<name>/         # one Workspace per Challenge (Challenge.lean + config.json + the untrusted Solution.lean)
.github/workflows/              # verify-submission.yml (untrusted-proof gate) + lean_action_ci.yml (build)
CONTEXT.md                      # glossary;  docs/adr/ # decisions
test_world.json                 # tracked test fixture (a valid starting world); regenerated by Shit/WorldRoundtrip.lean on build
world.json                      # git-ignored live save state
TODOS.md                        # task list (game/proofs + pipeline)
```

### Editing in VS Code

```bash
code .   # WSL: opens Windows VS Code over the WSL remote
```

Install the **Lean 4** extension (`leanprover.lean4`); it reads `lean-toolchain`, starts the language server, and shows proof goals and `#eval`/`#check` output inline. Opening the folder runs an initial `lake build`, so the first load can take a while.
