The symbolic frontend lets you describe intent first and numerical
representation second.

In practice that means you can write:

- symbolic states;
- symbolic operators and observables; and
- many zoo components and protocol inputs

without immediately rewriting everything in backend-specific math.

The gain is practical rather than philosophical:

- fewer model rewrites when you change backend;
- fewer backend-specific mistakes in user code;
- easier sharing of reusable states, circuits, and protocols; and
- a shorter path from a hardware idea to a working simulation.

The conversion point is `express`. QuantumSavory uses that boundary when you
pass symbolic objects to `initialize!`, `apply!`, or `observable`.

The limit is important: backend-agnostic does not mean backend-universal.
Backends still differ in what they can represent efficiently, or at all. A
stabilizer backend is still a stabilizer backend; a Gaussian backend is still a
Gaussian backend. The symbolic layer separates model description from backend
choice, but it does not erase backend math constraints.

So the right mental model is:

- symbolic objects describe what you want;
- the backend decides whether and how that object can be executed well.

Good next reads are "Symbolic Frontend", "Choosing a Backend and Modeling
Tradeoffs", and "Symbolic Expressions Reference".
