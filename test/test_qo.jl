using Test
using QuantumSavory
using QuantumOptics
using QuantumSavory: LazyPrePost

bs = GenericBasis(2),GenericBasis(2)
op0 = Operator(bs...,rand(2,2))
op21 = Operator(bs...,rand(2,2))
op22 = Operator(bs...,rand(2,2))
op31 = Operator(bs...,rand(2,2))
op32 = Operator(bs...,rand(2,2))
l2 = LazyPrePost(op21,op22)
l3 = LazyPrePost(op31,op32)
@test spre(op21)*spost(op22) ≈ spost(op22)*spre(op21)
@test spre(op21)*spost(op22)*op0 ≈ l2*op0
@test spre(op31)*spost(op32)*spre(op21)*spost(op22)*op0 ≈ (l3*l2)*op0 ≈ l3*(l2*op0)
@test (l2+l3) * op0 ≈ spre(op21)*spost(op22)*op0 + spre(op31)*spost(op32)*op0

op0a = Operator(bs...,rand(2,2))
op0b = Operator(bs...,rand(2,2))
opt0 = op0⊗op0a⊗op0b
b = basis(opt0)
@test embed(b,b,[1],l2)*opt0 ≈ (spre(op21)*spost(op22)*op0)⊗op0a⊗op0b
@test embed(b,b,[1],l2+l3)*opt0 ≈ (spre(op21)*spost(op22)*op0 + spre(op31)*spost(op32)*op0)⊗op0a⊗op0b
