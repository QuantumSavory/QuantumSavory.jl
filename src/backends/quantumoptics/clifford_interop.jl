import QuantumOpticsBase
import QuantumOptics
import QuantumClifford
import QuantumClifford: graphstate, stabilizerview, Stabilizer

export stab_to_ket

function stab_to_ket(s::Stabilizer)
    r,c = size(s)
    @assert r==c
    graph, hadamard_idx, iphase_idx, flips_idx = graphstate(s)
    ket = tensor(fill(copy(_s₊),c)...) # TODO fix this is UGLY
    for (;src,dst) in edges(graph)
        apply!(ket, [src,dst], _cphase)
    end
    for i in flips_idx
        apply!(ket, [i], _z)
    end
    for i in iphase_idx
        apply!(ket, [i], _phase)
    end
    for i in hadamard_idx
        apply!(ket, [i], _hadamard)
    end
    ket
end

express_nolookup(x::StabilizerState, ::QuantumOpticsRepr) = stab_to_ket(stabilizerview(x.stabilizer))
