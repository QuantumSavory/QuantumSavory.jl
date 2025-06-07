include("./setup.jl")

L = 10^1        # Total network distance in km
η_c = 0.9       # Coupling coefficient
ϵ_g = 0.001     # Gate error rate
n = 4           # Number of segments

q = 32          # Number of qubits per interface
T2 = 1.0        # T2 Dephasing time in seconds

c = 2e5         # Speed of light in km/s
l_att = 20      # Attenuation length in km

l0 = L / n      # Internode distance in km
p_ent = 0.5*η_c^2*exp(-l0/l_att)    # Entanglement generation probability
ξ = 0.25ϵ_g     # Measurement error rate
F = 1-1.25ϵ_g   # Initial bellpair fidelity

t_comms = fill(l0/c, n)     # Internode communication time in seconds
# distil_sched = distil_scheds[(L, n, ϵ_g, η_c)]  # Distillation schedule
distil_sched = fill(true, floor(Int, log2(n)))


net_param = NetworkParam(n, q; T2, F, p_ent, ϵ_g, ξ, t_comms, distil_sched)
network = Network(net_param, rng=Xoshiro(1))

figures = @time simulate!(network; PLOT=true)
for fig in figures
    display(fig)
    sleep(2)
end
