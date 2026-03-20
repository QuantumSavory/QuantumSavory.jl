include("./setup.jl")

L = 10^4        # Total network distance in km
η_c = 0.9       # Coupling coefficient
ϵ_g = 0.001     # Gate error rate
n = 512           # Number of segments

q = 1024          # Number of qubits per interface
T2 = 1.0        # T2 Dephasing time in seconds

c = 2e5         # Speed of light in km/s
l_att = 20      # Attenuation length in km

l0 = L / n      # Internode distance in km
p_ent = 0.5*η_c^2*exp(-l0/l_att)    # Entanglement generation probability
ξ = 0.25ϵ_g     # Measurement error rate
F = 1-1.25ϵ_g   # Initial bellpair fidelity

t_comms = fill(l0/c, n)     # Internode communication time in seconds
distil_sched = distil_scheds[(L, n, ϵ_g, η_c)]  # Distillation schedule


net_param = NetworkParam(n, q; T2, F, p_ent, ϵ_g, ξ, t_comms, distil_sched)
network = Network(net_param, rng=Xoshiro(1))

# @time simulate!(network)

sim = simulate_iter!(network)
video_path = "./results/3_large_network.mp4"
record(network.fig, video_path, 1:nsteps(net_param); framerate=2) do i
    iterate(sim, nothing)
end
