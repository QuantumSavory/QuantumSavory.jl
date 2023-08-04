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

function (circuit::Purify2to1)(purifiedL,purifiedR,sacrificedL,sacrificedR)
    gate, basis, parity = if circuit.leaveout==:X
        CNOT, σˣ, 0
    elseif circuit.leaveout==:Z
        CPHASE, σˣ, 0
    elseif circuit.leaveout==:Y
        YCX, σʸ, 1
    end
    apply!((sacrificedL,purifiedL),gate)
    apply!((sacrificedR,purifiedR),gate)
    measa = project_traceout!(sacrificedL, basis)
    measb = project_traceout!(sacrificedR, basis)
    success = (measa ⊻ measb == parity)
    if !success
        traceout!(purifiedL)
        traceout!(purifiedR)
    end
    success
end

struct Purify3to1 <: AbstractCircuit
    fixtwice::Symbol
    function Purify3to1(fixtwice)
        if fixtwice ∉ (:X, :Y, :Z)
            throw(ArgumentError(lazy"""
            `Purify3to1` can represent one of three purification circuits (see its docstring),
            parameterized by the argument `fixtwice` which has to be one of `:X`, `:Y`, or `:Z`.
            You have instead chosen `$(repr(fixtwice))` which is not a valid option.
            Investigate where you are creating a purification circuit of type `Purify3to1`
            and ensure you are passing a valid argument.

            The `fixtwice` parameter represents the error that the putifying circuit will 
            'fix twice', meaning for example, for a fixtwice Y circuit (original double selection),
            Purify3to1 will represent the succesive applying of a leaveout Z and then a leaveout X
            Purify2to1 circuit, with coincidence measurments pushed to the end.
            """))
        else
            new(fixtwice)
        end
    end
end

struct PurifyStringent <: AbstractCircuit
end

function coin(basis, pair::Array, parity=0)
    measa = project_traceout!(pair[1], basis)
    measb = project_traceout!(pair[2], basis)
    success = (measa ⊻ measb == parity)
    success
end

function (circuit::PurifyStringent)(purifiedL,purifiedR,sacrificedL::Array,sacrificedR::Array)
    gate1, gate2 = ZCZ, XCZ
    basis = X
    size = 13
    sacrificedL_1 = sacrificedL[1]
    sacrificedR_1 = sacrificedR[1]
    sacrificedL_2 = sacrificedL[2]
    sacrificedR_2 = sacrificedR[2]
    free_index = 3
    apply!((purifiedL, sacrificedL_1), gate1)
    apply!((purifiedR, sacrificedR_1), gate1)

    apply!((sacrificedR_1, sacrificedR_2), gate1)
    apply!((sacrificedL_1, sacrificedL_2), gate1)

    if coin(σˣ, [sacrificedL_1, sacrificedR_1]) == 1
        # sacrifice pairs
        sacrificedL_1 = sacrificedL[free_index]
        sacrificedL_2 = sacrificedL[free_index+1]

        sacrificedR_1 = sacrificedR[free_index]
        sacrificedR_2 = sacrificedR[free_index+1]

        free_index = free_index + 2
    end

    if coin(σˣ, [sacrificedL_2, sacrificedR_2]) == 1
        # sacrifice pairs
        sacrificedL_1 = sacrificedL[free_index]
        sacrificedL_2 = sacrificedL[free_index+1]

        sacrificedR_1 = sacrificedR[free_index]
        sacrificedR_2 = sacrificedR[free_index+1]

        free_index = free_index + 2
    end

    apply!((purifiedL, sacrificedL_1), gate2)
    apply!((purifiedR, sacrificedR_1), gate2)

    apply!((sacrificedL_1, sacrificedL_2), gate1)
    apply!((sacrificedR_1, sacrificedR_2), gate1)

    # Green rectangle

    if coin(σˣ, [sacrificedL_1, sacrificedR_1]) == 1
        # sacrifice pairs
        sacrificedL_1 = sacrificedL[free_index]
        sacrificedL_2 = sacrificedL[free_index+1]

        sacrificedR_1 = sacrificedR[free_index]
        sacrificedR_2 = sacrificedR[free_index+1]

        free_index = free_index + 2
    end

    if coin(σˣ, [sacrificedL_2, sacrificedR_2]) == 1
        # sacrifice pairs
        sacrificedL_1 = sacrificedL[free_index]
        sacrificedL_2 = sacrificedL[free_index+1]

        sacrificedR_1 = sacrificedR[free_index]
        sacrificedR_2 = sacrificedR[free_index+1]

        free_index = free_index + 2
    end

    apply!((sacrificedL_1, sacrificedL_2), gate2)
    apply!((sacrificedR_1, sacrificedR_2), gate2)

    if coin(σˣ, [sacrificedL_2, sacrificedR_2]) == 1
        # sacrifice pairs
        sacrificedL_1 = sacrificedL[free_index]
        sacrificedL_2 = sacrificedL[free_index+1]

        sacrificedR_1 = sacrificedR[free_index]
        sacrificedR_2 = sacrificedR[free_index+1]

        free_index = free_index + 2
    end

    apply!((sacrificedL_1, sacrificedL_2), gate1)
    apply!((sacrificedR_1, sacrificedR_2), gate1)

    # EO Rectangle

    apply!((purifiedL, sacrificedL_1), gate1)
    apply!((purifiedR, sacrificedR_1), gate1)

    if coin(σˣ, [sacrificedL_2, sacrificedR_2]) == 1
        # sacrifice pairs

        sacrificedL_1 = sacrificedL[free_index]
        sacrificedL_2 = sacrificedL[free_index+1]

        sacrificedR_1 = sacrificedR[free_index]
        sacrificedR_2 = sacrificedR[free_index+1]

        free_index = free_index + 2
    end
    
    apply!((sacrificedL_1, sacrificedL_2), gate1)
    apply!((sacrificedR_1, sacrificedR_2), gate1)

    # Green rectangle

    if coin(σˣ, [sacrificedL_1, sacrificedR_1]) == 1
        # sacrifice pairs
        sacrificedL_1 = sacrificedL[free_index]
        sacrificedL_2 = sacrificedL[free_index+1]

        sacrificedR_1 = sacrificedR[free_index]
        sacrificedR_2 = sacrificedR[free_index+1]

        free_index = free_index + 2
    end

    if coin(σˣ, [sacrificedL_2, sacrificedR_2]) == 1
        # sacrifice pairs
        sacrificedL_1 = sacrificedL[free_index]
        sacrificedL_2 = sacrificedL[free_index+1]

        sacrificedR_1 = sacrificedR[free_index]
        sacrificedR_2 = sacrificedR[free_index+1]

        free_index = free_index + 2
    end

    apply!((sacrificedL_1, sacrificedL_2), gate2)
    apply!((sacrificedR_1, sacrificedR_2), gate2)

    if coin(σˣ, [sacrificedL_2, sacrificedR_2]) == 1
        # sacrifice pairs
        sacrificedL_1 = sacrificedL[free_index]
        sacrificedL_2 = sacrificedL[free_index+1]

        sacrificedR_1 = sacrificedR[free_index]
        sacrificedR_2 = sacrificedR[free_index+1]

        free_index = free_index + 2
    end

    apply!((sacrificedL_1, sacrificedL_2), gate1)
    apply!((sacrificedR_1, sacrificedR_2), gate1)

    # EO Rectangle

    apply!((purifiedL, sacrificedL_1), gate2)
    apply!((purifiedR, sacrificedR_1), gate2)

    if coin(σˣ, [sacrificedL_2, sacrificedR_2]) == 1
        # sacrifice pairs
        sacrificedL_1 = sacrificedL[free_index]
        sacrificedL_2 = sacrificedL[free_index+1]

        sacrificedR_1 = sacrificedR[free_index]
        sacrificedR_2 = sacrificedR[free_index+1]

        free_index = free_index + 2
    end
    
    apply!((sacrificedL_1, sacrificedL_2), gate1)
    apply!((sacrificedR_1, sacrificedR_2), gate1)

    if coin(σˣ, [sacrificedL_1, sacrificedR_1]) == 1
        # sacrifice pairs
        sacrificedL_1 = sacrificedL[free_index]
        sacrificedL_2 = sacrificedL[free_index+1]

        sacrificedR_1 = sacrificedR[free_index]
        sacrificedR_2 = sacrificedR[free_index+1]

        free_index = free_index + 2
    end

    if coin(σˣ, [sacrificedL_2, sacrificedR_2]) == 1
        # sacrifice pairs
        sacrificedL_1 = sacrificedL[free_index]
        sacrificedL_2 = sacrificedL[free_index+1]

        sacrificedR_1 = sacrificedR[free_index]
        sacrificedR_2 = sacrificedR[free_index+1]

        free_index = free_index + 2
    end

    

end

function (circuit::Purify3to1)(purifiedL,purifiedR,sacrificedL::Array,sacrificedR::Array)
    gate1, gate2, basis1, basis2, parity1, parity2 = if circuit.fixtwice==:X
        YCZ, ZCX, σʸ, σᶻ, 1, 0
    elseif circuit.fixtwice==:Y
        ZCX, XCZ, σᶻ, σˣ, 0, 0
    elseif circuit.fixtwice==:Z
        XCZ, YCZ, σˣ, σʸ, 0, 1
    end

    apply!((purifiedL, sacrificedL[1]),gate1)
    apply!((purifiedR, sacrificedR[1]),gate1)

    apply!((sacrificedR[1],sacrificedR[2]),gate2)
    apply!((sacrificedL[1],sacrificedL[2]),gate2)

    measa1 = project_traceout!(sacrificedL[1], basis1)
    measb1 = project_traceout!(sacrificedR[1], basis1)
    measa2 = project_traceout!(sacrificedL[2], basis2)
    measb2 = project_traceout!(sacrificedR[2], basis2)
    success1 = (measa1 ⊻ measb1 == parity1)
    success2 = (measa2 ⊻ measb2 == parity2)

    if !(success1 && success2)
        traceout!(purifiedL)
        traceout!(purifiedR)
    end
    (success1 && success2)
end

end # module
