using QuantumSavory.StatesZoo: stateparametersrange, stateparameters
import QuantumSavory.StatesZoo: stateexplorer, stateexplorer!

const lls = express.([L0⊗L0,L1⊗L0,L0⊗L1,L1⊗L1])
const bells = express.([L0⊗L0+L1⊗L1,L0⊗L0-L1⊗L1,L0⊗L1+L1⊗L0,L0⊗L1-L1⊗L0]) ./ sqrt(2)
const B = sum(projector(l,b') for (l,b) in zip(lls,bells))

angleifnotε(x) = angle(x) * (abs(x)<0.001 ? 0.0 : 1.0)

function stateexplorer(S)
    fig = Figure()
    stateexplorer!(fig,S)
end

function stateexplorer!(fig,S)
    params = stateparameters(S)
    paramdict = stateparametersrange(S)

    if !isempty(params)
        perfect = express(S((paramdict[p].good for p in params)...))
        perfect = perfect/tr(perfect)
    end

    colormap=:cyclic_mrybm_35_75_c68_n256
    colorrange=(-pi,pi)
    nbxpoints = 30
    εf = 0.0001

    f3dρ = fig[1:2,1:2]
    fcb = f3dρ[1,3]
    fparamsF = fig[3,1:2]
    fparamsTr = fig[4,1:2]
    fparamsS = fig[5,1:2]

    aparamsF = []
    aparamsTr = []
    sliders = []
    for (i, param) in enumerate(params)
        (;min,max,good) = paramdict[param]
        ε = (max-min)*εf
        xs = range(min+ε,max-ε,length=nbxpoints)

        slider = Slider(fparamsS[1, i], range=xs, startvalue=good)
        push!(sliders, slider)

        af = Axis(fparamsF[1,i] , xticks=[min,max], yticks=([0,0.5,1],["0","½","1"]), xgridvisible=true, ygridvisible=true, ylabel = i==1 ? "F" : "")
        at = Axis(fparamsTr[1,i], xticks=[min,max], yticks=([0,0.5,1],["0","½","1"]), xgridvisible=true, ygridvisible=true, xlabel=string(param), ylabel= i==1 ? "tr(ρ)" : "")
        push!(aparamsF, af)
        push!(aparamsTr, at)
    end

    for (i, (aparamF, aparamTr, slider, param)) in enumerate(zip(aparamsF, aparamsTr, sliders, params))
        (;min,max,good) = paramdict[param]
        ε = (max-min)*εf
        xs = range(min+ε,max-ε,length=nbxpoints)

        data = lift((s.value for s in sliders)...) do paramvalues...
            states = [express(S((p==param ? x : pv for (p,pv) in zip(params,paramvalues))...)) for x in xs]
            Fs = abs.(tr.(states .* (perfect',)))
            Trs = abs.(tr.(states))
            state = express(S(paramvalues...))
            F = abs(tr(state * perfect'))
            Tr = abs(tr(state))
            Fs ./= Trs
            Fs, Trs, F, Tr
        end
        Fs = @lift $data[1]
        Trs = @lift $data[2]
        Fgood = @lift [$data[3]/$data[4]]
        Trgood = @lift [$data[4]]
        good = @lift [$(slider.value)]
        lines!(aparamF, xs, Fs)
        vlines!(aparamF, good, color=:gray80)
        scatter!(aparamF, good, Fgood, marker=:x, color=:black)
        lines!(aparamTr, xs, Trs)
        vlines!(aparamTr, good, color=:gray80)
        scatter!(aparamTr, good, Trgood, marker=:x, color=:black)
    end

    for a in [aparamsF..., aparamsTr...]
        ylims!(a, (-0.05,1.05))
        deregister_interaction!.((a,), keys(interactions(a)))
    end

    ρticks = ((1:4).+0.5, ["00","10","01","11"])
    ρBticks = ((1:4).+0.5, ["Φ+","Φ-","Ψ+","Ψ-"])
    a3dρ = Axis3(f3dρ[1,1],
        xticks=ρticks, yticks=ρticks, yreversed=true, zticks=([0,0.25,0.5,0.75,1],["","¼","½","¾","1"]),
        xlabel="", ylabel="", zlabel="",
        title="ρ (Z basis)"
    )
    a3dρB = Axis3(f3dρ[1,2],
        xticks=ρBticks, yticks=ρBticks, yreversed=true, zticks=([0,0.25,0.5,0.75,1],["","¼","½","¾","1"]),
        xlabel="", ylabel="", zlabel="",
        title="ρ (Bell basis)"
    )

    if isempty(params) # TODO fix the code repetition on both sides
        ρdata = S.data
        ρBdata = (B*S*B').data
        for ij in keys(ρdata)
            mesh!(a3dρ, Rect3f(ij[1],ij[2],0,0.9,0.9,abs(ρdata[ij])+1e-4); color=angleifnotε(ρdata[ij]), colorrange, colormap)
        end
        for ij in keys(ρdata)
            mesh!(a3dρB, Rect3f(ij[1],ij[2],0,0.9,0.9,abs(ρBdata[ij])+1e-4); color=angleifnotε(ρBdata[ij]), colorrange, colormap)
        end
    else
        ρsym = lift((s.value for s in sliders)...) do parameters...
            S(parameters...)
        end
        ρ = lift(ρsym) do ρsym
            ρ = express(ρsym)
            return (ρ/tr(ρ))
        end
        ρdata = @lift $(ρ).data
        ρBdata = @lift (B*$ρ*B').data
        for ij in keys(ρdata[])
            mesh!(a3dρ, @lift Rect3f(ij[1],ij[2],0,0.9,0.9,abs($(ρdata)[ij])+1e-4); color=(@lift angleifnotε($(ρdata)[ij])), colorrange, colormap)
        end
        for ij in keys(ρdata[])
            mesh!(a3dρB, @lift Rect3f(ij[1],ij[2],0,0.9,0.9,abs($(ρBdata)[ij])+1e-4); color=(@lift angleifnotε($(ρBdata)[ij])), colorrange, colormap)
        end
    end

    zlims!(a3dρ,0,1)
    zlims!(a3dρB,0,1)

    Colorbar(fcb; colorrange, colormap, ticks=([-π,0,π],["-π","0","π"]), label="phase")

    fig
end
