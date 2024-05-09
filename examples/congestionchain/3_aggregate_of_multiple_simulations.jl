include("setup.jl")

using GLMakie # For plotting
GLMakie.activate!(inline=false)

##
# Demo visualizations of the performance of the network
##

function prepare_singlerun(
    ;
    len = 5,                    # Number of registers in the chain
    regsize = 2,                # Number of qubits in each register
    T2 = 100.0,                 # T2 dephasing time of all qubits
    F = 0.97,                   # Fidelity of the raw Bell pairs
    entangler_wait_time = 0.1,  # How long to wait if all qubits are busy before retring entangling
    entangler_busy_λ = 0.5,     # How long it takes to establish a newly entangled pair (Exponential distribution parameter)
    swapper_wait_time = 0.1,    # How long to wait if all qubits are unavailable for swapping
    swapper_busy_time = 0.55,   # How long it takes to swap two qubits
    consume_wait_time = 0.1,    # How long to wait if there are no qubits ready for consumption
)
    sim, network = simulation_setup(len, regsize, T2)

    noisy_pair = noisy_pair_func(F)
    for (;src, dst) in edges(network)
        @process entangler(sim, network, src, dst, noisy_pair, entangler_wait_time, entangler_busy_λ)
    end

    for node in vertices(network)
        @process swapper(sim, network, node, swapper_wait_time, swapper_busy_time)
    end

    ts = Ref(Float64[])
    fidXX = Ref(Float64[])
    fidZZ = Ref(Float64[])
    @process consumer(sim, network, 1, len, consume_wait_time,ts,fidXX,fidZZ)

    sim, network, ts, fidXX, fidZZ
end

##

link_lengths = 3:40 # change the range of chain lengths being simulated
results = Vector{Any}(undef,length(link_lengths))

Threads.@threads for i in eachindex(link_lengths)
    conf = Dict( # change the settings here
        :len => link_lengths[i],
        :regsize => 2,
        :T2 => 100.0,
        :F => 0.97,
        :entangler_busy_λ => 0.5,
        :swapper_busy_time => 0.5
    )
    sim, network, ts, fidXX, fidZZ = prepare_singlerun(; conf...)
    run(sim, 1000) # run for 1000 time units
    results[i] = (ts, fidXX, fidZZ)
    @info "Finished run $(i) of $(length(link_lengths)) -- the chain length was $(link_lengths[i])"
end

##

avgt = [mean(res[1][]) for res in results]
avgxx = [mean(res[2][]) for res in results]
avgzz = [mean(res[3][]) for res in results]

F = Figure(size=(600,600))
ax1 = Axis(F[1,1], ylabel="avg time to connection")
scatter!(ax1, link_lengths, avgt)
ylims!(ax1,0,nothing)
ax2 = Axis(F[2,1], ylabel="XX Stabilizer\nExpectation")
scatter!(ax2, link_lengths, avgxx)
ylims!(ax2,0,1)
ax3 = Axis(F[3,1], ylabel="ZZ Stabilizer\nExpectation", xlabel="chain length")
scatter!(ax3, link_lengths, avgzz)
ylims!(ax3,0,1)
save("stats_vs_chainlength.png", F)
display(F)
