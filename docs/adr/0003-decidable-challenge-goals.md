# Challenges are `Decidable P` goals so one immutable statement admits both proof and disproof

A Challenge states its Proposition `P` as a decision goal, `def <name> : Decidable P := sorry`,
rather than `theorem <name> : P := sorry`. The untrusted agent's Solution supplies the instance:
`isTrue h` (a proof of `P`) ⇒ **Proven** (green), or `isFalse h` (a proof of `¬P`) ⇒ **Disproven**
(red). Because the statement (`Decidable P`) is identical in both cases, the agent can prove *or*
disprove `P` without editing the Challenge — which keeps comparator's "statement unchanged" rule
satisfied either way. comparator confirms a valid `Decidable P` instance exists; a separate step
inspects whether it is `isTrue`/`isFalse` to set the colour. This is a genuine obligation: a
Proposition like `not_outside` has no pre-existing `Decidable` instance, so the agent must construct
the decision together with its embedded proof.

## Considered Options

- **Plain `theorem <name> : P := sorry`** — only admits a proof; a disproof would prove `¬P`, a
  *different* statement, which comparator rejects. No way to express Disproven. (Still used for the
  few non-decidable Propositions, e.g. universally-quantified ones like `Contrapositive`.)
- **Paired theorems `P` and `¬P`** — two `sorry` theorems per Proposition; the agent proves one.
  Workable but doubles the statements and needs comparator to accept "prove any one of these" rather
  than "prove all."
- **`Decidable P` goal (chosen)** — one statement covers both outcomes; the verdict is read from the
  instance's head constructor.

## Consequences

- A **Disproven** (red) Challenge signals that the underlying code or theorems likely need a
  follow-up change; **Proven** (green) needs none. (Idea: auto-open an issue on Disproven.)
- The verdict requires a post-verification step that evaluates/inspects the accepted instance for
  `isTrue` vs `isFalse` — comparator alone only attests that *some* valid `Decidable P` was provided.
