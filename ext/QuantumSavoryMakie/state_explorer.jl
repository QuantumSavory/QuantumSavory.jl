using QuantumSavory.StatesZoo: stateparametersrange, stateparameters
import QuantumSavory.StatesZoo: stateexplorer, stateexplorer!
import Printf: @sprintf

const lls = express.([L0⊗L0,L1⊗L0,L0⊗L1,L1⊗L1])
const bells = express.([L0⊗L0+L1⊗L1,L0⊗L0-L1⊗L1,L0⊗L1+L1⊗L0,L0⊗L1-L1⊗L0]) ./ sqrt(2)
const B = sum(projector(l,b') for (l,b) in zip(lls,bells))

angleifnotε(x) = angle(x) * (abs(x)<0.001 ? 0.0 : 1.0)

const PARAMCOLS = 5

function stateexplorer(S)
    sliders = length(stateparameters(S))
    rows = (sliders-1)÷PARAMCOLS+1
    yplot = 220
    ytext = 40
    ysliders = 230*rows
    y = yplot+ytext+ysliders
    fig = Figure(size=(600,y))
    ret = stateexplorer!(fig,S)
    Makie.rowsize!(fig.layout, 1, Makie.Relative(yplot/y))
    Makie.rowsize!(fig.layout, 2, Makie.Relative(ytext/y))
    Makie.rowsize!(fig.layout, 3, Makie.Relative(ysliders/y))
    ret
end

function stateexplorer!(fig,S)
    params = stateparameters(S)
    paramdict = stateparametersrange(S)

    colormap=:cyclic_mrybm_35_75_c68_n256
    colorrange=(-pi,pi)
    nbxpoints = 30
    εf = 0.0001

    slowcompute = false
    slowthreshold = 1.0/nbxpoints


    if !isempty(params)
        timed_result = @timed express(S((paramdict[p].good for p in params)...))
        @info "timing first state computation" timed_result
        slowcompute = timed_result.time > slowthreshold
        @info "triggering slowcompute?" slowcompute
        perfect = timed_result.value
        perfect = perfect/tr(perfect)
    end

    f3dρ = fig[1,1]
    fcb = f3dρ[1,3]
    ftext = fig[2,1]
    fparams = fig[3,1]
    #fparamsF = fig[3,1:2]
    #fparamsTr = fig[4,1:2]
    #fparamsS = fig[5,1:2]

    aparamsF = []
    aparamsTr = []
    sliders = []
    for (i, param) in enumerate(params)
        subfparam = fparams[(i-1)÷PARAMCOLS+1,(i-1)%PARAMCOLS+1]
        (;min,max,good) = paramdict[param]
        ε = (max-min)*εf
        xs = range(min+ε,max-ε,length=nbxpoints)

        slider = Slider(subfparam[3,1], range=xs, startvalue=good)
        push!(sliders, slider)

        if !slowcompute
        af = Axis(subfparam[1,1] , xticks=[min,max], yticks=([0,0.5,1],["0","½","1"]), xgridvisible=true, ygridvisible=true, ylabel = i==1 ? "F" : "", xticklabelrotation=pi/4*2/3)
        at = Axis(subfparam[2,1], xticks=[min,max], yticks=([0,0.5,1],["0","½","1"]), xgridvisible=true, ygridvisible=true, xlabel=string(param), ylabel= i==1 ? "tr(ρ)" : "", xticklabelrotation=pi/4*2/3)
        xlims!(af, min, max)
        xlims!(at, min, max)
        push!(aparamsF, af)
        push!(aparamsTr, at)
        else
        at = Axis(subfparam[1:2,1], xticks=[min,max], xgridvisible=false, ygridvisible=false, xlabel=string(param), ylabel="", xticklabelrotation=pi/4*2/3)
        xlims!(at, min, max)
        Makie.hideydecorations!(at)
        Makie.hidespines!(at, :t,:r,:l)
        end
    end
    slowcompute && Makie.Label(ftext[1,4], "This model is slow!\n Skipping parameter sweep plots.", tellheight=false, tellwidth=false)

    if !slowcompute
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
    xlims!(a3dρ,1-0.1,5)
    ylims!(a3dρ,5,1-0.1)
    xlims!(a3dρB,1-0.1,5)
    ylims!(a3dρB,5,1-0.1)

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
        ρnotnormalized = lift(ρsym) do ρsym
            return express(ρsym)
        end
        Tr = @lift abs(tr($ρnotnormalized))
        ρ = lift(ρnotnormalized, Tr) do ρnotnormalized, Tr
            return ρnotnormalized/Tr
        end
        F = @lift abs(tr($ρ*perfect'))
        ρdata = @lift $(ρ).data
        ρBdata = @lift (B*$ρ*B').data
        for ij in keys(ρdata[])
            mesh!(a3dρ, @lift Rect3f((ij[1],ij[2],0),(0.9,0.9,abs($(ρdata)[ij])+1e-4)); color=(@lift angleifnotε($(ρdata)[ij])), colorrange, colormap)
        end
        for ij in keys(ρdata[])
            mesh!(a3dρB, @lift Rect3f((ij[1],ij[2],0),(0.9,0.9,abs($(ρBdata)[ij])+1e-4)); color=(@lift angleifnotε($(ρBdata)[ij])), colorrange, colormap)
        end
        textF = @lift "F="*@sprintf("%g",$F)
        textTr = @lift "Tr="*@sprintf("%g",$Tr)
        Makie.Label(ftext[1,1], textF, tellheight=false, tellwidth=false, halign=:left)
        Makie.Label(ftext[1,2], textTr, tellheight=false, tellwidth=false, halign=:left)
    end

    zlims!(a3dρ,-0.001,1.001)
    zlims!(a3dρB,-0.001,1.001)

    Colorbar(fcb; colorrange, colormap, ticks=([-π,0,π],["-π","0","π"]), label="phase", tellheight=false)

    fig
end
