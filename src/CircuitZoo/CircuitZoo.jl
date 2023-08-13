module CircuitZoo

using QuantumSavory
using DocStringExtensions

export Purify2to1

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

"""
$TYPEDEF

## Fields:

$FIELDS

A simple purification circuit sacrificing a Bell pair to produce another.
The circuit is parameterized by a single `leaveout` symbol argument
which specifies which of the three possible Pauli errors are to be left undetected.
A simple purificaiton circuit is not capable of detecting all errors.

If an error was detected, the circuit returns `false` and the state is reset.
If no error was detected, the circuit returns `true`.

The sacrificial qubits are removed from the register.

```jldoctest
julia> a = Register(2)
       b = Register(2)
       bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2
       initialize!((a[1], b[1]), bell)
       initialize!((a[2], b[2]), bell);

julia> Purify2to1(:X)(a[1], b[1], a[2], b[2])
true

julia> observable((a[1], b[1]), projector(bell))
1.0 + 0.0im
```

However, an error might have occurred on the initial state. If the error is detectable,
the `Purify2to1` circuit will return `false` and the state will be reset.

```jldoctest
julia> a = Register(2)
       b = Register(2)
       bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2
       initialize!((a[1], b[1]), bell)
       initialize!((a[2], b[2]), bell)
       apply!(a[1], Z);

julia> Purify2to1(:X)(a[1], b[1], a[2], b[2])
false

julia> a
Register with 2 slots: [ Qubit | Qubit ]
  Slots:
    nothing
    nothing
```

In some cases the error might not be detectable. In that case, the `Purify2to1` circuit
does return `true`, but as you can see below, the state is not what we would expect from
a successful purification.

```jldoctest
julia> a = Register(2)
       b = Register(2)
       bell = (Z₁⊗Z₁+Z₂⊗Z₂)/√2
       initialize!((a[1], b[1]), bell)
       initialize!((a[2], b[2]), bell)
       apply!(a[1], X);

julia> Purify2to1(:X)(a[1], b[1], a[2], b[2])
true

julia> observable((a[1], b[1]), projector(bell))
0.0 + 0.0im
```
"""
struct Purify2to1 <: AbstractCircuit
    """A symbol specifying which of the three Pauli errors to leave undetectable."""
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
    gate, basis = if circuit.leaveout==:X
        CNOT, σˣ
    elseif circuit.leaveout==:Z
        XCZ, σᶻ
    elseif circuit.leaveout==:Y
        ZCY, σʸ
    end
    apply!((sacrificedL,purifiedL),gate)
    apply!((sacrificedR,purifiedR),gate)
    measa = project_traceout!(sacrificedL, basis)
    measb = project_traceout!(sacrificedR, basis)
    success = measa == measb
    if !success
        traceout!(purifiedL)
        traceout!(purifiedR)
    end
    success
end

"""
$TYPEDEF

Fields:

$FIELDS

A purification circuit sacrificing 2 Bell pairs to produce another.
The circuit is parameterized by a `fixtwice` symbol argument
which specifies which of the three possible Pauli errors is fixed twice.
This purificaiton circuit is capable of detecting all errors.

If an error was detected, the circuit returns `false` and the state is reset.
If no error was detected, the circuit returns `true`.

The sacrificial qubits are removed from the register.

```jldoctest
julia> a = Register(2)
       b = Register(2)
       c = Register(2)
       initalize!(a[1:2], bell)
       initalize!(b[1:2], bell)
       initalize!(c[1:2], bell)


julia> Purify3to1(:X)(a[1], a[2], [b[1], c[1]], [b[2], c[2]])
false
```

"""

struct Purify3to1 <: AbstractCircuit
    """The error to be fixed twice"""
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

function (circuit::Purify3to1)(purifiedL,purifiedR,sacrificedL::Array,sacrificedR::Array)
    gate1, gate2, basis1, basis2 = if circuit.fixtwice==:X
        ZCY, XCZ, σʸ, σᶻ
    elseif circuit.fixtwice==:Y
        XCZ, CNOT, σᶻ, σˣ
    elseif circuit.fixtwice==:Z
        CNOT, ZCY, σˣ, σʸ
    end

    apply!((sacrificedL[1], purifiedL),gate1)
    apply!((sacrificedR[1], purifiedR),gate1)

    apply!((sacrificedR[2],sacrificedR[1]),gate2)
    apply!((sacrificedL[2],sacrificedL[1]),gate2)

    measa1 = project_traceout!(sacrificedL[1], basis1)
    measb1 = project_traceout!(sacrificedR[1], basis1)
    measa2 = project_traceout!(sacrificedL[2], basis2)
    measb2 = project_traceout!(sacrificedR[2], basis2)
    
    success1 = measa1 == measb1
    success2 = measa2 == measb2

    if !(success1 && success2)
        traceout!(purifiedL)
        traceout!(purifiedR)
    end
    (success1 && success2)
end

function coin(basis, pair::Array, parity=0)
    measa = project_traceout!(pair[1], basis)
    measb = project_traceout!(pair[2], basis)
    success = (measa ⊻ measb == parity)
    success
end

struct StringentHead <: AbstractCircuit
    type::Symbol
    function StringentHead(type)
        if type ∉ (:X, :Z)
            throw(ArgumentError(lazy"""
            `type` has to be one of `:X`, or `:Z`.
            You have instead chosen `$(repr(fixtwice))` which is not a valid option.
            Investigate where you are creating a purification circuit of type `StringentHead`
            and ensure you are passing a valid argument.
            """))
        else
            new(type)
        end
    end
end

function (circuit::StringentHead)(purifiedL, purifiedR, sacrificedL, sacrificedR)
    gate, success = if circuit.type == :Z
        ZCZ, true
    else
        XCZ, true
    end
    apply!((purifiedL, sacrificedL[1]), gate)
    apply!((purifiedR, sacrificedR[1]), gate)
    apply!((sacrificedR[1], sacrificedR[2]), ZCZ)
    apply!((sacrificedL[1], sacrificedL[2]), ZCZ)

    success = success & coin(σˣ, [sacrificedL[1], sacrificedR[1]])
    success = success & coin(σˣ, [sacrificedL[2], sacrificedR[2]])

    success
end

struct StringentBody <: AbstractCircuit
    type::Symbol
    expedient::Bool
    function StringentBody(type, expedient=false)
        if type ∉ (:X, :Z)
            throw(ArgumentError(lazy"""
            `type` has to be one of `:X`, or `:Z`.
            You have instead chosen `$(repr(fixtwice))` which is not a valid option.
            Investigate where you are creating a purification circuit of type `StringentBody`
            and ensure you are passing a valid argument.
            """))
        else
            new(type, expedient)
        end
    end
end

function (circuit::StringentBody)(purifiedL, purifiedR, sacrificedL, sacrificedR)
    gate, success = if circuit.type == :Z
        ZCZ, true
    else
        XCZ, true
    end
    ## Indices for emulating pair creation
    i1 = 1
    i2 = 1
    sacrificedL1 = sacrificedL[1:1]
    sacrificedR1 = sacrificedR[1:1]

    sacrificedL2 = circuit.expedient ? sacrificedL[2:3] : sacrificedL[2:4]
    sacrificedR2 = circuit.expedient ? sacrificedR[2:3] : sacrificedR[2:4]

    apply!((sacrificedL1[i1], sacrificedL2[i2]), XCZ)
    apply!((sacrificedR1[i1], sacrificedR2[i2]), XCZ)
    success = success & coin(σˣ, [sacrificedL2[i2], sacrificedR2[i2]])
    i2 = i2 + 1

    apply!((sacrificedL1[i1], sacrificedL2[i2]), ZCZ)
    apply!((sacrificedR1[i1], sacrificedR2[i2]), ZCZ)
    success = success & coin(σˣ, [sacrificedL2[i2], sacrificedR2[i2]])

    apply!((purifiedL, sacrificedL1[i1]), gate)
    apply!((purifiedR, sacrificedR1[i1]), gate)

    if !circuit.expedient 
        i2 = i2 + 1
        apply!((sacrificedL1[i1], sacrificedL2[i2]), ZCZ)
        apply!((sacrificedR1[i1], sacrificedR2[i2]), ZCZ)

        success = success & coin(σˣ, [sacrificedL2[i2], sacrificedR2[i2]])
    end

    success = success & coin(σˣ, [sacrificedL1[i1], sacrificedR1[i1]])

    success

end


"""
$TYPEDEF

Fields:

$FIELDS

The STRINGENT purification circuit 

If an error was detected, the circuit returns `false` and the state is reset.
If no error was detected, the circuit returns `true`.

The sacrificial qubits are removed from the register.

```jldoctest
julia> r = Register(26, rep())
    for i in 1:13
        initialize!(r[(2*i-1):(2*i)], bell)
    end

julia> PurifyStringent()(r[1], r[2],
        [r[3], r[5], r[7], r[9], r[11], r[13], r[15], r[17], r[19], r[21], r[23], r[25]],
        [r[4], r[6], r[8], r[10], r[12], r[14], r[16], r[18], r[20], r[22], r[24], r[26]])
    true

```

"""

struct PurifyStringent <: AbstractCircuit
end



function (circuit::PurifyStringent)(purifiedL,purifiedR,sacrificedL,sacrificedR)
    success = true
    stringentHead_Z = StringentHead(:Z)
    stringentHead_X = StringentHead(:X)
    stringentBody_Z = StringentBody(:Z)
    stringentBody_X = StringentBody(:X)

    success = success & stringentHead_Z(purifiedL, purifiedR, sacrificedL[1:2], sacrificedR[1:2])
    success = success & stringentHead_X(purifiedL, purifiedR, sacrificedL[3:4], sacrificedR[3:4])
    success = success & stringentBody_Z(purifiedL, purifiedR, sacrificedL[5:8], sacrificedR[5:8])
    success = success & stringentBody_X(purifiedL, purifiedR, sacrificedL[9:12], sacrificedR[9:12])
    
    success
end

struct PurifyExpedient <: AbstractCircuit
end

function (circuit::PurifyExpedient)(purifiedL,purifiedR,sacrificedL,sacrificedR)
    success = true
    stringentHead_Z = StringentHead(:Z)
    stringentHead_X = StringentHead(:X)
    stringentBody_Z = StringentBody(:Z, true)

    success = success & stringentHead_Z(purifiedL, purifiedR, sacrificedL[1:2], sacrificedR[1:2])
    success = success & stringentHead_X(purifiedL, purifiedR, sacrificedL[3:4], sacrificedR[3:4])
    success = success & stringentBody_Z(purifiedL, purifiedR, sacrificedL[5:7], sacrificedR[5:7])
    success = success & stringentBody_Z(purifiedL, purifiedR, sacrificedL[8:10], sacrificedR[8:10])
    
    success
end

end # module
