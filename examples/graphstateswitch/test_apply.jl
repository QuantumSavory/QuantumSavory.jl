using QuantumSavory

n = 15

# Case 1: register initialized with X1 product state
reg = Register(n, QuantumOpticsRepr())
initialize!(reg[1:n], reduce(⊗, fill(X1,n)))

timed_compile = @elapsed apply!((reg[1]), H)
timed_compute = @elapsed apply!((reg[1]), H)
@info timed_compile, timed_compute

# Case 2: register initialized with X1 individual states
reg = Register(n, QuantumOpticsRepr())
for i in 1:n initialize!(reg[i], X1) end
timed_compile = @elapsed apply!(reg[1], H)
timed_compute = @elapsed apply!(reg[1], H)

@info timed_compile, timed_compute