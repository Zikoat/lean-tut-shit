import Shit.Proofs

/-- Untrusted Solution to the `contrapositive` Challenge. -/
theorem contrapositive (p q : Prop) : Contrapositive p q :=
  fun hpq hnq hp => hnq (hpq hp)
