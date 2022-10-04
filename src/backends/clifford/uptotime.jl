function uptotime!(state::QuantumClifford.MixedDestabilizer, idx::Int, background, Δt)
    prob, op = paulinoise(background, Δt)
    if rand() > prob
        QuantumClifford.apply!(state, op(idx))
    end
    state
end

function paulinoise(T2::T2Dephasing, Δt)
    exp(-Δt/T2.t2), QuantumClifford.sZ
end
