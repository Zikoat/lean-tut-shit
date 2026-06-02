import Shit.Proofs

theorem contrapositive (p q : Prop) : Contrapositive p q := by
  intro hpq hnq hp
  exact hnq (hpq hp)
