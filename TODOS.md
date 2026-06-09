# TODOs

Two tracks: the **ProofFarmer game & proofs**, and the **proof-verification pipeline**
(CI / comparator). See [README.md](./README.md) for the project vision + research
questions, [CONTEXT.md](./CONTEXT.md) for the glossary, and [docs/adr/](./docs/adr/) for
decisions. Items are grouped by status, not priority.

## Game & proofs

* [ ] **Full loop migration onto `WorldEnv`** — `Shit/Interaction.lean` (PR #5) landed the `WorldEnv` effect record + pure `Action`/`run` Program + layered parse + `loadWithRecovery`, but the gameplay `while True` loop in `ProofFarmer.lean` still uses ad-hoc `render`/`sleep` and a hardcoded harvest/move sequence. Generalize: add a `render` field to `WorldEnv`, extract a pure `renderToString` from `ProofFarmer.render_terminal`/`drawBoard`, and drive the loop via `Action`/`run`. Touches working game code — keep it surgical and TDD it; the `while True` IO driver stays the untested edge, only the structurally-terminating pieces are unit-testable. (Relates to the `sleep`/`render`-optional + `wait_ticks` equivalence item below.)
* [ ] `move` should wait 200 ticks _(today `move` carries no tick cost by design — see the comment in `World.lean`; cost added at the call site)_
* [ ] `move` should render
* [x] `move` should wrap around _(modulo arithmetic in `World.lean` `move`; wraparound examples in `Shit/Proofs.lean`)_
* [ ] have a manual way of unlocking unlocks
* [ ] visually display unlocks and what they do
* [ ] add docstrings, same as the wiki / real game
* [ ] add `plant(Entities.bush)` command
* [ ] add the "plant" unlock
* [ ] make `sleep` and `render` optional, and prove that functions like `wait_ticks` with a `none` sleep and render are equivalent to a simple increment of ticks
* [ ] prove: as long as `unlock_expand_1` is not bought, `move` is the same as a noop _(only specific default-world examples exist in `Proofs.lean`, not the general theorem)_
* [ ] prove: as long as `unlock_expand_1` is not bought, `move .east` and `move .west` are noops _(same — examples only)_
* [ ] add `can_harvest()` — returns whether the crop has fully grown, and itself waits 1 tick. Motivation: after `unlock_speed_1`, a tight `loop { harvest }` is too fast for the crop to regrow; harvesting an ungrown crop resets its growth timer and yields nothing. With `can_harvest()` you can poll in a loop and the crop will eventually be ready

## Proof-verification pipeline

Trusted side owns the World, the Program, and Challenge authoring; the untrusted side
produces only Solutions (proofs), verified by comparator (statement diff + axiom permit
list + Lean kernel). Glossary in CONTEXT.md.

### Open

* [ ] **Upgrade toolchain to latest Lean** — bump `lean-toolchain` v4.29.0-rc1 → latest stable; move Mathlib, cslib, comparator, lean4export (and verify landrun) to compatible versions together.
* [ ] **Cross-run `.lake` caching in CI** (`actions/cache`) — cache the `.lake` build dir, the Mathlib olean cache, and the built tool binaries (comparator, lean4export, landrun), keyed on `lake-manifest.json` + `lean-toolchain`, so one run's output can be reused by the next.
* [ ] **Speed up local `lake env comparator <config.json>`** — ~48–67 s locally (dominated by compiling the Solution inside landrun); fast in CI (warm cache). Don't investigate/reproduce — just fix the perf.
* [ ] **Upgrade WSL kernel to 6.7+ (Landlock ABI v4)** — box is kernel 6.6 = ABI v3, so landrun runs `--best-effort`: FS isolation works but network restrictions (ABI v4) are not enforced, so a Solution's elaboration-time code could make network calls when comparator runs locally. CI (ubuntu-latest) likely has ABI v4+, so network is contained there.
The approach for the next four is decided in [ADR-0002](docs/adr/0002-untamperable-verification-via-pull-request-target.md) (workflow-tamper + merge-eligibility). No live changes without go-ahead.

* [ ] **Move merge authority into a `pull_request_target` workflow** (per ADR-0002) — its definition and checkout come from the default branch, so the PR can't tamper with it. Extract **only** `Solution.lean` from the PR head; take lakefile/toolchain/`Challenge.lean`/`config.json` from the trusted base; run comparator inside landrun with the token kept out of the compile step's env; merge **only on its own ACCEPT verdict**, never on a green `verify` name. This closes both the workflow-tamper vector and the merge-eligibility scope (Challenge/config/workflow come from base, so a PR can't change them — only a checked `Solution.lean` can land).
* [ ] **Require fork-only submission, zero write access** (load-bearing, per ADR-0002) — a same-repo PR could enable native auto-merge itself and satisfy the spoofable `verify` name with a fake-green `pull_request` job. Don't gate merging on native check-based auto-merge.
* [ ] **Remove the current self-merge step** from `verify-submission.yml` — its `gh pr merge --auto` grants a same-repo PR a write token inside a definition the PR controls (today's live break, per ADR-0002).
* [ ] **Branch-protection defense-in-depth** — keep `verify` required + `strict` (closes the verify→merge TOCTOU) + enable `enforce_admins`; never treat the `verify` name as the security boundary (the token/privilege + fork boundaries are).

### Open questions raised in discussion (not yet scoped)

* [ ] **Resource / DoS bounds on the untrusted Solution** — no `timeout-minutes` on the verify job (GitHub default 6 h); landrun doesn't cap CPU/memory/time; a Solution can `set_option maxHeartbeats 0` and write an arbitrarily expensive proof → unbounded CI compute/cost. Soundness is unaffected (availability/cost only). **Decided:** put a wall-clock `timeout-minutes` on the comparator/proof-run step (in the `pull_request_target` workflow per ADR-0002), **~15 min as a starting value** to tune. A real-time cap bounds cost even against `maxHeartbeats 0` (which only disables the heartbeat limit, not the clock). Heartbeats (Lean's *deterministic* work budget — machine-independent, unlike wall-clock) were considered as the limiter instead, but (a) the untrusted file can override any budget with in-file `set_option maxHeartbeats 0` unless we forbid it, and (b) they only count elaboration/tactic work, not native compilation / `#eval` / kernel time. So keep wall-clock as the hard backstop; optionally *add* a trusted heartbeat budget + reject Solutions that set `maxHeartbeats`, for deterministic per-proof limits. Concurrency limits remain a secondary lever.
* [ ] **Enumerate the Trusted Computing Base** — the exact set whose bug or compromise would let a false proof merge: Lean kernel, lean4export, comparator's diff logic, landrun, the GitHub Actions runner, and the trusted config / permit list.
* [ ] **Challenge lifecycle & quality** — who authors Challenges; how we ensure a Challenge is well-formed, genuinely open, non-trivial, and true. States: Open (`sorry`, yellow) → Proven (green) or Disproven (red); most Propositions are `Decidable` so the agent may submit a proof or a disproof. Challenge shapes are not yet decided; in most cases exact `ticks` is not part of the required final-state assertion, but finiteness of `ticks` (i.e. termination) usually is.
* [ ] **Disproven → follow-up issue** — when a Challenge is Disproven (red), auto-create a GitHub issue to track the follow-up change to the underlying code/theorems (Proven needs none). Mechanism TBD.
* [ ] **Read the Proven/Disproven colour from the accepted instance** — Challenges are framed as `def <name> : Decidable P := sorry`; comparator confirms a valid `Decidable P` instance exists (statement unchanged, so a disproof needs no edit), but the green/red verdict depends on whether the instance is `isTrue` or `isFalse`. Add a step that inspects/evaluates the accepted instance to set the colour. (This resolves the earlier "disproof under statement-unchanged" question — the `Decidable P` goal is the chosen shape.)
* [ ] **Program representation** — whether the pure Program is a deeply-embedded AST (like the `Prog` inductive + `Terminates` in `Shit/Proofs.lean`) or a plain `World → World` function. Undecided; will emerge during implementation.
* [ ] **Observability / audit** — a trail of what was submitted and merged, by whom/what. A **derived status board** (each Challenge → Open/Proven/Disproven, with timestamps/attempt counts), generated from the repo, would be the dataset for the agent-accuracy/proof-churn research questions — but only matters once the project grows; not yet.
* [ ] **Recovery & re-solving** — there is no special rollback: deleting an accepted `Solution.lean` reverts its Challenge to Open and the agent re-solves. Two triggers: (1) a trusted code/theorem change that invalidates a previously-correct Solution — delete the Solution in the *same* change as the code change; (2) a **false proof** that slipped the pipeline — investigate + harden the pipeline, delete the Solution, then let the AI try again (to confirm the hardening now blocks it). A periodic re-verification sweep (re-run comparator / `lean4checker` over accepted Solutions) could surface case (1) automatically. The churn rate in case (1) is itself a research question.

### Done

* [x] Decide verifier: adopt `leanprover/comparator` (vs custom / lean-eval).
* [x] Define trust boundary & repo topology (trusted vs untrusted; per-Challenge Workspace).
* [x] Define submission constraints: untrusted AI may add exactly one `Solution.lean`, proof only.
* [x] Install & build toolchain: landrun, lean4export, comparator (pinned v4.29.0-rc1).
* [x] Author the first Challenge + config: Contrapositive (`Shit/Challenges/Contrapositive/`).
* [x] Wire CI: `verify-submission.yml` (file-allowlist guard → comparator → auto-merge); `lean_action_ci.yml` build (perf-fixed 25 min → ~78 s via Mathlib cache + library-only build + lint off).
* [x] Make repo public + branch protection (required check `verify`, 0 reviews, no force-push/deletion).
* [x] End-to-end PR test (positive + negative): PR #3 correct proof → comparator accept; PR #4 `sorry` → reject.
* [x] Enable repo auto-merge (`allow_auto_merge` + `delete_branch_on_merge`) → PR #3 auto-merged (squash); PR #4 correctly left unmerged.
* [x] Move the side-effecting `#eval` out of `Shit/Proofs.lean` → `Shit/WorldRoundtrip.lean`, so comparator's trusted compile surface is side-effect-free (on `master`, `9b166553`).
* [x] Install real ripgrep for lean-lsp `lean_local_search` (brew `rg` 15.1.0).

## Downstream / future (explicitly out of current scope)

Captured for later; **not** to be done in the current work item.

### Security canaries — "cakes"

* [ ] **"Cakes" — cryptographically signed canary keys spread across the environment.** For each cake, create one theorem that embeds the **public** key; the matching **private** key lives at the cake's location, and the untrusted AI can prove that theorem only by obtaining the private key. Seed locations (each a distinct access/exfiltration vector): the human's filesystem, the AI's filesystem, pushed to git, added as git credentials, the AI's environment variables, a public URL, the human's GitHub password, a pull-request description, the user's agent's memory, the untrusted agent's online context/memory — and every other credential the project uses. Provide a few **easily-accessible** cakes as a liveness check that the mechanism works; **most must never be reachable.** Crucial principle: inaccessibility must come from **sandboxing/security, not obscurity** — so the agent is given full transparency: source of every dependency used during verification, source of whatever it runs on (the OS, the verification pipeline, the GitHub Actions definitions, etc.), hints for related tasks, open bugs, and security advisories. The agent is **encouraged to use adversarial methods** — injecting comments/commands/human-readable instructions, jailbreaking the human's AI agent, finding vulnerabilities in the Lean kernel / OS / sandbox — to escalate access or capture cakes. A captured cake (other than the easy ones) = a real breach signal.
* [ ] **Unprovable tripwire theorems** — seed theorems that are *definitely* unprovable. If the agent ever "solves" one, that is itself proof of a vulnerability somewhere in the pipeline.

### Submission richness & accounting

* [ ] **Let the agent attach prose to a submission** — how it found/created the proof, methods it tried that failed, and an informal statement of the proof.
* [ ] **Let the agent suggest code changes** — when the theorem or code-under-test doesn't formally capture the informal intent, the agent may propose changes to the actual code/theorems.
* [ ] **Token accounting** — surface total tokens the agent used, ideally broken down per theorem.

### Better / faster proving

* [ ] **More effective theorem solving** — specialise the untrusted agents with specific tactics; dedicated theorem-proving agents.
* [ ] **Use `plausible` and cslib to find contradictions faster** (fast refutation / disproof).

### Authoring & pipeline ergonomics

* [ ] **Nicer test-authoring API** where the conclusion may be true or false. Options to explore: allow `sorry` anywhere and let the untrusted agent create the Challenges; or a CLI/pipeline that auto-generates Challenges (and removes Solutions).
* [ ] **Harden agent-running safety; actively try to break the pipeline** (red-team the whole system).
* [ ] **Audit `lean_action_ci.yml`** — is the lean-action CI necessary, and does it do anything useful, or is it redundant with the verify/comparator flow? Remove if redundant.

## Notes

- **Soundness gate** = the axiom permit list (`propext`, `Quot.sound`, `Classical.choice`) + transitive axiom tracking + the Lean kernel. The wide import surface (Mathlib — and cslib once wired up) is safe *because* any unpermitted axiom — including `sorryAx` and `native_decide`'s `Lean.ofReduceBool` — shows up in the theorem's transitive axiom footprint and is rejected.
- **Auto-merge is live** repo-wide; PR #3 (positive) merged, PR #4 (negative) remains open by design.
- The open pipeline items above came out of a breadth-first review of: soundness (settled), merge-eligibility, workflow integrity, sandbox isolation, resource/DoS, TCB, Challenge lifecycle, the untrusted agent, observability, recovery, toolchain, performance.
- Ephemeral handoff snapshots live in `/tmp/lean-tut-shit-handoff*.md` (not durable).
