# Proof Verification Pipeline

A pipeline that lets an untrusted AI submit Lean proofs for open theorems in this
trusted repo, verifies each submission against a strong threat model, and merges it
only if it genuinely proves the stated theorem.

## Language

**Proposition**:
The bare statement type of a Challenge, defined in `Shit/Proofs.lean` alongside the
project's other proofs (so Challenges can double as ProofFarmer tests). E.g.
`def Contrapositive (p q : Prop) : Prop := (p → q) → (¬q → ¬p)`.
_Avoid_: statement, type, goal

**Challenge**:
A trusted, read-only `Challenge.lean` that imports a Proposition and states it as a
named theorem with proof `sorry`. The thing a Solution must prove.
_Avoid_: problem, task

**Solution**:
The untrusted AI's single file `Solution.lean` containing only a proof of the
Challenge's named theorem (same statement, real proof). May import Mathlib/cslib. The
AI owns nothing else; there is no bridge and no reference proof.
_Avoid_: submission, answer, attempt

**Workspace**:
A per-Challenge directory holding that Challenge's `Challenge.lean`, `Solution.lean`,
and comparator `config.json`. One dir per Challenge so Solutions never collide.
_Avoid_: problem dir, folder

**Comparator**:
The trusted verifier (`leanprover/comparator`) that judges a Submission against a
Challenge: confirms the statement wasn't redefined, axioms are within the permit
list, no `sorry`, and the proof passes the Lean kernel.
_Avoid_: checker, judge, validator

**Permit list**:
The explicit set of axioms a Submission is allowed to depend on. Anything outside it
(notably `sorryAx`) fails verification. Default, shared by all Challenges: the three
standard Lean axioms `propext`, `Quot.sound`, `Classical.choice`.
_Avoid_: allowlist, whitelist

**Trusted side / Untrusted side**:
Trusted = human+AI who own the Challenge, the Permit list, and the CI config.
Untrusted = the AI that may only produce a Submission and nothing else.
_Avoid_: ours/theirs, internal/external

**Trusted import surface**:
The libraries a Challenge/Submission may import, all of which are therefore trusted:
core Lean, Mathlib, and cslib. Expanding this set is a deliberate trust-surface
decision (comparator trusts the Challenge's imports).
_Avoid_: dependencies, allowed libs
