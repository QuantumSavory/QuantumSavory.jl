using GLMakie
GLMakie.activate!()

f = Figure(resolution=(1200,900))
using QuantumSavory
using QuantumSavory.CircuitZoo: EntanglementSwap, Purify2to1Node, Purify3to1, Purify2to1, Purify3to1Node, AbstractCircuit
# legend and axis names
const bell = StabilizerState("XX ZZ")
# QOptics repr
const perfect_pair = (Z1⊗Z1 + Z2⊗Z2) / sqrt(2)
const perfect_pair_dm = SProjector(perfect_pair)
const mixed_dm = MixedState(perfect_pair_dm)
noisy_pair_func(F) = F*perfect_pair_dm + (1-F)*mixed_dm # TODO make a depolarization helper
simcount = 10000
leaveoutarr = [:X, :Y, :Z]

for i in 1:3
    leaveout = leaveoutarr[i]
    if i == 1
        ax = Axis(f[i, 1], title = "Single selection", xlabel = "input fidelity", ylabel = "output fidelity")
    else
        ax = Axis(f[i, 1])
    end
    range = 0:0.05:1
    finalfids = Float32[]
    successprob = Float32[]
    for fid in range
        successcount = 0
        finfid = 1
        noisy_pair = noisy_pair_func(fid)
        
        for _ in 1:simcount
            r = Register(4, QuantumOpticsRepr())
            initialize!(r[1:2], noisy_pair)
            initialize!(r[3:4], noisy_pair)
            output = Purify2to1(leaveout)(r[1:4]...)
            (output) && (successcount = successcount + 1)
            if output
                finfid = observable(r[1:2], projector(bell))
            end
        end
        push!(successprob, successcount/simcount)
        push!(finalfids, finfid)
    end
    initfids=collect(range)

    fids_lines = lines!(ax, (3 .* initfids .+ 1) ./ 4, finalfids)
    success_lines = lines!(ax, (3 .* initfids .+ 1) ./ 4, successprob)
    if i == 1
        axislegend(ax, [fids_lines, success_lines], ["fidelities", "success"], "Legend", position = :rb,
            orientation = :horizontal)
    end

end
for i in 1:3
    for j in 1:3
        if (i!=j)
            leaveout1 = leaveoutarr[i]
            leaveout2 = leaveoutarr[j]
            if i == 1 && j == 2
                ax = Axis(f[i,j+1], title = "Triple Selection")
            else
                ax = Axis(f[i, j+1])
            end
            range = 0:0.05:1
            finalfids = Float32[]
            successprob = Float32[]
            for fid in range
                successcount = 0
                finfid = 1
                noisy_pair = noisy_pair_func(fid)
                
                for _ in 1:simcount
                    r = Register(6, QuantumOpticsRepr())
                    initialize!(r[1:2], noisy_pair)
                    initialize!(r[3:4], noisy_pair)
                    initialize!(r[5:6], noisy_pair)
                    output = Purify3to1(leaveout1, leaveout2)(r[1], r[2], r[3], r[5], r[4], r[6])
                    (output) && (successcount = successcount + 1)
                    if output
                        finfid = observable(r[1:2], projector(bell))
                    end
                end
                push!(successprob, successcount/simcount)
                push!(finalfids, real(finfid))
            end
            initfids=collect(range)
        
            lines!(ax, (3 .* initfids .+ 1) ./ 4, finalfids)
            # This approach only works if we are using QuantumOptics. Other libraries may require calculating each individual fidelity.
            lines!(ax, (3 .* initfids .+ 1) ./ 4, successprob)
        else
            ax = Axis(f[i, j+1])
            hidexdecorations!(ax)
            hideydecorations!(ax)
            arr = ["X", "Y", "Z"]
            text!(ax, 0, 0, text=arr[i], align=(:center, :center))
        end
    end
end
f
save("three_to_one_purification_zecemii.png",f)

