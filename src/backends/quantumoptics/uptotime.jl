export krausops

function uptotime!(state::StateVector, idx::Int, background, Δt)
    state = dm(state)
    uptotime!(state, idx, background, Δt)
end

function uptotime!(state::Operator, idx::Int, background, Δt)
    nstate = zero(state)
    tmpl = zero(state)
    tmpr = zero(state)
    b = basis(state)
    e = isa(b,CompositeBasis) # TODO make this more elegant with multiple dispatch
    Ks = krausops(background, Δt, b)
    if isnothing(Ks) # TODO turn this into a dispatch on a trait of having a kraus representations
        # TODO code repetition with apply_noninstant!
        L = lindbladop(background,b)
        lindbladian = e ? embed(b,[idx],L) : L
        _, sol = timeevolution.master([0,Δt], state, identityoperator(b), [lindbladian])
        nstate.data .= sol[end].data
    else
        for k in Ks
            k = e ? embed(b,[idx],k) : k # TODO lazy product would be better maybe
            mul!(tmpl,k,state,1,0) # TODO there must be a prettier way to do this
            mul!(tmpr,tmpl,k',1,0)
            nstate.data .+= tmpr.data
        end
        # Suggestion for alternative implementation:
        # for k in Ks
        #     k = e ? embed(b, [idx], k) : k
        #     nstate .+= k * state * adjoint(k)
        # end
    end
    @assert abs(tr(nstate)) ≈ 1. # TODO maybe put under a debug flag
    nstate
end

# TODO these should not be necessary, just use QuantumSymbolics
const _b2 = SpinBasis(1//2)
const _h = spindown(_b2) # TODO is this a good decision... look at how clumsy the kraus ops are
const _s₊ = (_l+_h)/√2
const _s₋ = (_l-_h)/√2
const _i₊ = (_l+im*_h)/√2
const _i₋ = (_l-im*_h)/√2
const _lh = sigmap(_b2)
const _ll = projector(_l)
const _hh = projector(_h)
const _id = identityoperator(_b2)
const _z = sigmaz(_b2)
const _x = sigmax(_b2)
const _y = sigmay(_b2)
const _Id = identityoperator(_b2)
const _hadamard = (sigmaz(_b2)+sigmax(_b2))/√2
const _cnot = _ll⊗_Id + _hh⊗_x
const _cphase = _ll⊗_Id + _hh⊗_z
const _phase = _ll + im*_hh
const _iphase = _ll - im*_hh

function krausops(b::AbstractBackground, Δt, basis) # shortcircuit for backgrounds that work on a single basis
    return krausops(b, Δt)
end

# TODO move to QuantumSymbolics (and remove the above constants)
function krausops(T1::T1Decay, Δt) # TODO checks comparing krausops and lindbladops
    p = exp(-Δt/T1.t1) # TODO check this
    [√(1-p) * _lh, √p * _hh + _ll]
end

function krausops(T2::T2Dephasing, Δt)
    p = 1-exp(-Δt/T2.t2) # TODO check this
    [√(1-p/2) * _id, √(p/2) * _z]
    #[√(1-p) * _id, √(p) * _hh, √(p) * _ll]
end

function krausops(d::AmplitudeDamping, Δt, basis) # https://quantumcomputing.stackexchange.com/questions/6828/amplitude-damping-of-a-harmonic-oscillator
    nothing # TODO maybe encode this as a trait
end

# TODO add an amplitude damping example of transduction

function krausops(Depol::Depolarization, Δt)
    p = 1-exp(-Δt/Depol.τ) # TODO check this
    [√(1-3*p/4) * _id, √(p/4) * _x, √(p/4) * _y, √(p/4) * _z]
end
