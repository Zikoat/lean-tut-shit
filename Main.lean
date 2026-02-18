import Shit

def main : IO Unit :=
  IO.println s!"Hello, {hello}!"

#eval 1 + 2
#eval String.append "Hello, " "Lean!"

#eval if 1 > 2 then "y" else "n"

#eval String.append "yeetus" " feetus"
#eval 42 + 19
#eval String.append "A" (String.append "B" "C")
#eval String.append (String.append "A" "B") "C"
#check (1 - 2 : Int)

def myName : String := "Sigurd"

#eval String.append "hello " myName

def add1 (n) := n + 1
#eval add1 2
def mymax (n : Nat) (k : Nat) := if n < k then k else n

#eval mymax 1 2

def joinStringWith (a : String) (b : String) (c : String) : String :=
  String.append (String.append a b) c

#eval joinStringWith "a" "b" "c"

#check joinStringWith "a"

#check 1.1

structure MyPoint where
  x : Float
  y : Float

def origin : MyPoint := { x := 0, y := 0 }
#eval origin.x

structure RectangularPrism where
  height : Float
  width : Float
  depth : Float

def volume (p : RectangularPrism) : Float :=
  p.height * p.width * p.depth

structure Point where
  x : Float
  y : Float

structure Segment where
  p1 : Point
  p2 : Point

def length (l : Segment) : Float :=
  Float.sqrt ((Float.pow (l.p2.x - l.p1.x) 2) + (Float.pow (l.p2.y - l.p1.y) 2))

#eval length { p1 := { x := 2, y := 4 }, p2 := { x := 6, y := 8 } }
#check Segment.p1

def plus (n : Nat) (k : Nat) : Nat :=
  match k with
  | Nat.zero => n
  | Nat.succ k' => Nat.succ (plus n k')

#check plus 3 2
#reduce plus 3 2
#eval plus 3 2

set_option trace.Meta.Tactic.simp true in
example : plus 3 2 = 5 := by
  simp [plus]


def times (n : Nat) (k : Nat) : Nat :=
  match k with
  | Nat.zero => Nat.zero
  | Nat.succ k' => plus n (times n k')

def minus (n : Nat) (k : Nat) : Nat :=
  match k with
  | Nat.zero => n
  | Nat.succ k' => Nat.pred (minus n k')

#eval Nat.pred 0
#eval Nat.pred 2
#eval minus 10 3
#eval times 3 2

-- def div (n : Nat) (k : Nat) : Nat :=
--   if n < k then
--     0
--   else Nat.succ (div (n - k) k)

#check  List Nat

structure PPoint (α  : Type) where
  x : α
  y : α

def natOrigin : PPoint Nat :=
  { x := 3, y := 3 }

#check natOrigin

def noop: (_:Unit)->  Unit := fun b=>b
def noop2 (_:Unit):Unit := ()
def noop3 (_:Unit) := ()
def noop4 : Unit → Unit :=
  fun a => a

#check noop
#check noop2
#check noop3
#check noop4
#eval noop ()

partial def infiniteLoop (n:Nat) :Nat
  := infiniteLoop n

def nonZero (n:Nat):Nat :=
  match n with
  | Nat.zero => default
  | Nat.succ k => Nat.succ k

def last {α :Type} (xs:List α ):Option α :=
match xs with
| [] => none
| y::List.nil=>some y
| _::ys=>last ys

#eval last [1,2,4]
#check last

def List.findFirst? {α :Type}
  (xs:List α )
  (predicate : α -> Bool)
  : Option α :=
match xs with
| [] => none
| y :: ys =>
  if(predicate y) then y else List.findFirst? ys predicate


def isNonZero(a:Nat):Bool :=
match a with
| Nat.zero => false
|Nat.succ _ => true

#eval List.findFirst? [0,0,0,2,3,0,] isNonZero

def Prod.switch {α β : Type} (pair : α × β ): β × α :=
(pair.snd, pair.fst)

#eval Prod.switch ("hello", "world")
