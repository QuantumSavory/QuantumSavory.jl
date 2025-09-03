function Base.show(io::IO, m::MIME"image/png", prot::QuantumSavory.ProtocolZoo.AbstractProtocol)
    f = Figure()
    protshowimage(f, prot)
    show(io, m, f)
end

"""Similar to `show(io, ::MIME"", ...)`, but private to avoid piracy. Instead of an IO instance, it takes a Makie axis."""
function protshowimage(subfig, prot)
    a = Axis(subfig[1,1])
    hidedecorations!(a)
    hidespines!(a)
    text = "protocol of type\n$(typeof(prot))\ndoes not support rich visualization"
    text!(a,0,0;text,align=(:center,:center))
end

function protshowimage(subfig, prot::QuantumSavory.ProtocolZoo.EntanglementConsumer)
    a = Axis(subfig[1,1], xlabel="Time", ylabel="Observable")
    t = [t for (t, _, _) in prot._log]
    zz = [z for (_, z, _) in prot._log]
    xx = [x for (_, _, x) in prot._log]
    scatter!(a, t, zz, label="ZZ")
    scatter!(a, t, xx, label="XX")
    hlines!(a, 0.0, color=:gray)
    hlines!(a, 1.0, color=:gray)
    axislegend(a, position=:lb)
end
