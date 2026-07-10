import QuantumInterface: apply!, observable, project_traceout!
using LinearAlgebra

struct ITensorRepr <: QuantumSymbolics.AbstractRepresentation end
const ITR = ITensorRepr()

struct TensorNetworkState
    tensors::Vector{ITensor}
    sites::Vector{Index}
end

default_repr(::TensorNetworkState) = ITR
ispadded(::TensorNetworkState) = false

function subsystemcompose(states::TensorNetworkState...)
    TensorNetworkState(
        vcat([s.tensors for s in states]...),
        vcat([s.sites for s in states]...)
    )
end

function newstate(::Qubit, ::ITensorRepr)
    s = Index(2, "Qubit")
    t = ITensor(s)
    t[s=>1] = 1.0
    t[s=>2] = 0.0
    TensorNetworkState([t], [s])
end

function apply!(state::TensorNetworkState, indices::Base.AbstractVecOrTuple{Int}, operation::Symbolic{AbstractOperator})
    op_qo = express(operation, QOR, UseAsOperation())
    mat = op_qo.data
    
    op_sites = state.sites[indices]
    n_sites = length(op_sites)
    dims = fill(2, 2 * n_sites)
    mat_reshaped = reshape(Matrix(mat), dims...)
    
    link_sites = [Index(2, "Link") for _ in 1:n_sites]
    
    for t in state.tensors
        for i in 1:n_sites
            if hasinds(t, op_sites[i])
                replaceind!(t, op_sites[i], link_sites[i])
            end
        end
    end
    
    out_inds = reverse(op_sites)
    in_inds = reverse(link_sites)
    
    op_tensor = itensor(mat_reshaped, out_inds..., in_inds...)
    push!(state.tensors, op_tensor)
    
    return state
end

function observable(state::TensorNetworkState, indices::Base.AbstractVecOrTuple{Int}, operation::AbstractMatrix)
    mat = operation
    op_sites = state.sites[indices]
    n_sites = length(op_sites)
    dims = fill(2, 2 * n_sites)
    mat_reshaped = reshape(Matrix(mat), dims...)
    
    out_inds = prime.(reverse(op_sites))
    in_inds = reverse(op_sites)
    op_tensor = itensor(mat_reshaped, out_inds..., in_inds...)
    
    all_inds = unique(vcat([collect(inds(t)) for t in state.tensors]...))
    internal_inds = filter(i -> i ∉ state.sites, all_inds)
    sim_map = [i => sim(i) for i in internal_inds]
    
    bra_tensors = ITensor[]
    for t in state.tensors
        t_bra = dag(t)
        if length(sim_map) > 0
            t_bra = replaceinds(t_bra, sim_map...)
        end
        for s in op_sites
            if hasinds(t_bra, s)
                t_bra = replaceind(t_bra, s, prime(s))
            end
        end
        push!(bra_tensors, t_bra)
    end
    
    net = vcat(state.tensors, bra_tensors, [op_tensor])
    res = reduce(*, net)
    return real(scalar(res))
end

function observable(state::TensorNetworkState, indices::Base.AbstractVecOrTuple{Int}, operation)
    op_qo = express(operation, QOR)
    return observable(state, indices, op_qo.data)
end

function project_traceout!(state::TensorNetworkState, stateindex::Int, basis::Symbolic{AbstractOperator})
    project_traceout!(state, stateindex, eigvecs(basis))
end

function project_traceout!(state::TensorNetworkState, stateindex::Int, psis::Base.AbstractVecOrTuple{<:Symbolic{AbstractKet}})
    site = state.sites[stateindex]
    
    probs = Float64[]
    for p in psis
        p_qo = express(p, QOR)
        vec = Matrix(p_qo.data)
        mat = vec * vec'
        prob = observable(state, [stateindex], mat)
        push!(probs, prob)
    end
    
    branch_probs = cumsum(probs)
    if !(branch_probs[end] ≈ 1.0)
        branch_probs = branch_probs ./ branch_probs[end]
    end
    
    r = rand()
    j = findfirst(>=(r), branch_probs)
    if isnothing(j)
        j = length(branch_probs)
    end
    
    prob_j = probs[j]
    
    p_qo = express(psis[j], QOR)
    vec = Matrix(p_qo.data)
    p_itensor = itensor(vec, site)
    p_bra = dag(p_itensor)
    
    push!(state.tensors, p_bra)
    
    state.tensors[1] = state.tensors[1] / sqrt(prob_j)
    
    deleteat!(state.sites, stateindex)
    
    return j, nothing
end
