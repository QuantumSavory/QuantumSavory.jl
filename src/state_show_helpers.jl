function _to_dm(state::Ket)
    dm(state)
end

function _to_dm(state::Operator)
    state
end

_to_dm(::Any) = nothing

function _nqubits_qo(state::Union{Ket,Operator})
    nsubsystems(state)
end

function _is_qubit_state(state::Union{Ket,Operator})
    b = basis(state)
    if b isa SpinBasis
        return length(b) == 2
    elseif b isa CompositeBasis
        return all(sub -> sub isa SpinBasis && length(sub) == 2, b.bases)
    end
    false
end

function _bloch_vector(ρ::Operator)
    m = ρ.data
    rx = real(m[1, 2] + m[2, 1])
    ry = real(im * (m[1, 2] - m[2, 1]))
    rz = real(m[1, 1] - m[2, 2])
    (rx, ry, rz)
end

function _purity(ρ::Operator)
    real(tr(ρ * ρ))
end

function _von_neumann_entropy(ρ::Operator)
    m = Matrix(ρ.data)
    evals = real.(LinearAlgebra.eigvals(m))
    s = 0.0
    for λ in evals
        if λ > 1e-15
            s -= λ * log2(λ)
        end
    end
    s
end

function _dm_matrix(ρ::Operator)
    Matrix{ComplexF64}(ρ.data)
end

function _state_vector(ψ::Ket)
    Vector{ComplexF64}(ψ.data)
end

function _basis_labels(n::Int)
    [string(i, base=2, pad=n) for i in 0:(2^n - 1)]
end

function _top_amplitudes(ψ::Ket, k::Int)
    v = ψ.data
    n = _nqubits_qo(ψ)
    labels = _basis_labels(n)
    amps = [(labels[i], v[i]) for i in eachindex(v)]
    sort!(amps, by=x -> abs2(x[2]), rev=true)
    amps[1:min(k, length(amps))]
end

function _top_probabilities(ρ::Operator, k::Int)
    m = ρ.data
    n = _nqubits_qo(ρ)
    labels = _basis_labels(n)
    probs = [(labels[i], real(m[i,i])) for i in 1:size(m,1)]
    sort!(probs, by=x -> x[2], rev=true)
    probs[1:min(k, length(probs))]
end

function _reduced_dm(ρ::Operator, keep::Int)
    n = nsubsystems(ρ)
    traceout_indices = [i for i in 1:n if i != keep]
    ptrace(ρ, traceout_indices)
end

function _pauli_expectations_1q(ρ::Operator)
    m = ρ.data
    ex = real(m[1, 2] + m[2, 1])
    ey = real(im * (m[1, 2] - m[2, 1]))
    ez = real(m[1, 1] - m[2, 2])
    (ex, ey, ez)
end

function _clifford_stabilizer_strings(state::QuantumClifford.MixedDestabilizer)
    stab = QuantumClifford.stabilizerview(state)
    [string(stab[i]) for i in 1:length(stab)]
end
