# shit

This project is a work in progress to translate the game *The Farmer Was Replaced* to Lean.

The end-game state is to have a theorem of the form: "provide a function which unlocks the last unlock and then terminates in finite time, and prove that it does that".

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
Main.lean          # `shit` exe — Lean tutorial scratchpad
ProofFarmer.lean   # `farmer` exe — the farming simulation entry point
Shit.lean          # library root
Shit/World.lean    # World state, Pos, bounds invariant (myPos_valid), move/unlock, JSON load/save
Shit/Proofs.lean   # proofs about the world (bounds, move wrap-around, round-trip)
Shit/Basic.lean    # `hello` helper
test_world.json    # tracked test fixture (a valid starting world)
world.json         # git-ignored live save state
TODOS.md           # task list
```

### Editing in VS Code

```bash
code .   # WSL: opens Windows VS Code over the WSL remote
```

Install the **Lean 4** extension (`leanprover.lean4`); it reads `lean-toolchain`, starts the language server, and shows proof goals and `#eval`/`#check` output inline. Opening the folder runs an initial `lake build`, so the first load can take a while.
