# Auto-merge untrusted-AI proofs verified by comparator, with no human review

An untrusted AI submits a proof (`Submission.lean`) of an open Challenge as a PR. We
adopt `leanprover/comparator` (with `landrun` + `lean4export`) to verify each
Submission against the trusted `Challenge.lean`: the statement must be unchanged, the
proof must use only the permitted axioms (default: `propext`, `Quot.sound`,
`Classical.choice`), contain no `sorry`, and pass the Lean kernel. A blocking CI
file-allowlist check ensures the PR touches *only* its `Submission.lean`. When both
checks are green the PR **auto-merges with no per-submission human review**.

This is deliberate: trust is invested **once** — in the Challenge, the comparator
config, the permit list, and the CI — not per submission. The whole point is that
comparator is a purpose-built, kernel-backed security boundary strong enough to accept
an adversarial proof without a human reading it. We rejected build-our-own (reimplements
a security tool; easy version misses statement-redefinition and axiom attacks) and
human-in-the-loop approval (defeats the goal of trusting the verifier, not the prover).

## Consequences

- The accepted-proof store is append-only: `Challenge.lean` keeps its `sorry` as an
  immutable spec; "proven" means "an accepted Submission exists." Proofs are never
  inlined into the trusted theorem.
- Security rests on: comparator's soundness, landrun sandboxing, the Lean kernel, and
  the `.lake` dir not being pre-compromised — the same trust assumptions comparator
  documents.
- Fork-based isolation (stronger than same-repo PR) is deferred until the PR flow shows
  limits.
