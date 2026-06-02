
example: p ∧ q ↔ q ∧ p :=
  ⟨
    fun h => And.intro h.right h.left
    ,
    fun h => And.intro h.right h.left
     ⟩


example : p ∨ q ↔ q ∨ p :=
  ⟨ fun h => h.elim (fun hp => Or.inr hp) (fun hq => Or.inl hq),
    fun h => h.elim (fun hq => Or.inr hq) (fun hp => Or.inl hp) ⟩

def absurdity: Prop := 0 = 1

theorem n_absurdity: ¬absurdity :=
sorry
-- fun h => Nat.noConfusion h
