using QuantumSavory
using QuantumSavory.CircuitZoo

a = Register(1)
b = Register(2)
bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2
initialize!(a[1], X1)  # Initialize `a[1]` in |+⟩ state
initialize!((b[1], b[2]), bell)  # Initialize `b` with a bell pair

correction = EntanglementFusion()(a[1], b[1])
isassigned(b[1])==false  # the target qubit is traced out 
if correction==2 apply!(b[2], X) end # apply correction if needed

# Now bell pair is fused into a
real(observable((a[1], b[2]), projector(bell)))