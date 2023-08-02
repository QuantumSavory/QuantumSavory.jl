module CircuitZoo

using QuantumSavory

abstract type AbstractCircuit end

struct EntanglementSwap <: AbstractCircuit
end

function (::EntanglementSwap)(localL, remoteL, lacalR, remoteR)
    apply!((localL, lacalR), CNOT)
    xmeas = project_traceout!(localL, σˣ)
    zmeas = project_traceout!(lacalR, σᶻ)
    if xmeas==2
        apply!(remoteL, Z)
    end
    if zmeas==2
        apply!(remoteR, X)
    end
    xmeas, zmeas
end

struct Purify2to1 <: AbstractCircuit
    leaveout::Symbol
    function Purify2to1(leaveout)
        if leaveout ∉ (:X, :Y, :Z)
            throw(ArgumentError(lazy"""
            `Purify2to1` can represent one of three purification circuits (see its docstring),
            parameterized by the argument `leaveout` which has to be one of `:X`, `:Y`, or `:Z`.
            You have instead chosen `$(repr(leaveout))` which is not a valid option.
            Investigate where you are creating a purification circuit of type `Purify2to1`
            and ensure you are passing a valid argument.
            """))
        else
            new(leaveout)
        end
    end
end

struct Purify3to1 <: AbstractCircuit
    leaveout::Symbol
    function Purify3to1()
        new()
    end
end

function (circuit::Purify2to1)(purifiedL,purifiedR,sacrificedL,sacrificedR)
    gate, basis, parity = if circuit.leaveout==:X
        CNOT, σˣ, 0
    elseif circuit.leaveout==:Z
        CPHASE, σˣ, 0
    elseif circuit.leaveout==:Y
        error("TODO this needs to be implemented")
    end
    apply!((sacrificedL,purifiedL),gate)
    apply!((sacrificedR,purifiedR),gate)
    measa = project_traceout!(sacrificedL, basis)
    measb = project_traceout!(sacrificedR, basis)
    success = measa ⊻ measb == parity
    if !success
        traceout!(purifiedL)
        traceout!(purifiedR)
    end
    success
end

function (circuit::Purify3to1)(purifiedL,purifiedR,sacrificedL1,sacrificedR1,sacrificedL2,sacrificedR2)
    gate, basis1, basis2, parity = CNOT, σˣ, σᶻ, 0


    apply!((sacrificedL1,purifiedL),gate)
    apply!((sacrificedR1,purifiedR),gate)


    apply!((sacrificedR1,sacrificedR2),gate)
    apply!((sacrificedL1,sacrificedL2),gate)

    measa1 = project_traceout!(sacrificedL1, basis1)
    measb1 = project_traceout!(sacrificedR1, basis1)


    measa2 = project_traceout!(sacrificedL2, basis2)
    measb2 = project_traceout!(sacrificedR2, basis2)



    success1 = measa1 ⊻ measb1 == parity

    success2 = measa2 ⊻ measb2 == parity

    if !(success1 && success2)
        traceout!(purifiedL)
        traceout!(purifiedR)
    end
    (success1 && success2)
end



end # module
