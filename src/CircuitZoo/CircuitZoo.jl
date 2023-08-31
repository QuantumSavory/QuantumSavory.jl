module CircuitZoo

using QuantumSavory
using DocStringExtensions

export Purify2to1

abstract type AbstractCircuit end

"""Number of qubits taken by a predefined circuit.

Part of the `QuantumSavory.CircuitZoo.AbstractCircuit` interface.
"""
function inputqubits end

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

inputqubits(::EntanglementSwap) = 4


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

inputqubits(circuit::Purify2to1) = 4

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

A purification circuit sacrificing 2 Bell qubits to produce another qubit.
The circuit is parameterized by a single `leaveout` symbol argument
which specifies which of the three possible Pauli errors are to be left undetected.
A simple purificaiton circuit is not capable of detecting all errors.

This circuit returns the array of measurements made.

This circuit is the same as the Purifiy2to1 one but it works on individual qubits
(i.e. only one qubit of a pair)

```jldoctest
julia> a = Register(2)
       b = Register(2)
       initalize!(a[1:2], bell)
       initalize!(b[1:2], bell)


julia> Purify2to1Node(:X)(a[1], b[1]) == Purify2to1Node(:X)(a[2], b[2])
false
```
"""
struct Purify2to1Node <: AbstractCircuit
    """A symbol specifying which of the three Pauli errors to leave undetectable."""
    leaveout::Symbol
    function Purify2to1Node(leaveout)
        if leaveout ∉ (:X, :Y, :Z)
            throw(ArgumentError(lazy"""
            `Purify2to1Node` is a Purify2to1 circuit that only operates on one member of the pair
            """))
        else
            new(leaveout)
        end
    end
end

inputqubits(circuit::Purify2to1Node) = 2

function (circuit::Purify2to1Node)(purified,sacrificed)
    gate, basis = if circuit.leaveout==:X
        CNOT, σˣ
    elseif circuit.leaveout==:Z
        XCZ, σᶻ
    elseif circuit.leaveout==:Y
        ZCY, σʸ
    end
    apply!((sacrificed,purified),gate)
    measb = project_traceout!(sacrificed, basis)
    measb
end



"""
$TYPEDEF

Fields:

$FIELDS

A purification circuit sacrificing a Bell pair to produce another.
The circuit is parameterized by a `leaveout1`, and a `leaveout2` symbol argument
which specifies the leaveout of each of the two purification subcircuits
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


julia> Purify3to1(:Z, :Y)(a[1], a[2], b[1], c[1], b[2], c[2])
false
```
"""
struct Purify3to1 <: AbstractCircuit
    """The error to be fixed twice"""
    leaveout1::Symbol
    leaveout2::Symbol
    function Purify3to1(leaveout1, leaveout2)
        if leaveout1 ∉ (:X, :Y, :Z) && leaveout2 ∉ (:X, :Y, :Z)
            throw(ArgumentError(lazy"""
            `Purify3to1` can represent one of three purification circuits (see its docstring),
            parameterized by the argument `leaveout1` and `leaveout2` which has to be one of `:X`, `:Y`, or `:Z`.
            You have instead chosen `$(repr(leaveout1))`, `$(repr(leaveout1))` which is not a valid option.
            Investigate where you are creating a purification circuit of type `Purify3to1`
            and ensure you are passing a valid argument.
            """))
        else
            new(leaveout1, leaveout2)
        end
    end
end

inputqubits(circuit::Purify3to1) = 6

function (circuit::Purify3to1)(purifiedL, purifiedR, sacrificedL1, sacrificedL2, sacrificedR1, sacrificedR2)
    dictionary_measurement = Dict(:X => σˣ, :Y => σʸ, :Z => σᶻ)
    if circuit.leaveout1 != :Y || circuit.leaveout2 != :X
        dictionary_gate = Dict(:X => CNOT, :Y => ZCY, :Z => XCZ)
    else
        dictionary_gate = Dict(:X => CNOT, :Y => XCY, :Z => XCZ)
    end
    gate1, gate2, basis1, basis2 = dictionary_gate[circuit.leaveout1], dictionary_gate[circuit.leaveout2], dictionary_measurement[circuit.leaveout1], dictionary_measurement[circuit.leaveout2]
    apply!((sacrificedL1, purifiedL),gate1)
    apply!((sacrificedR1, purifiedR),gate1)

    apply!((sacrificedR2,sacrificedR1),gate2)
    apply!((sacrificedL2,sacrificedL1),gate2)

    measa1 = project_traceout!(sacrificedL1, basis1)
    measb1 = project_traceout!(sacrificedR1, basis1)
    measa2 = project_traceout!(sacrificedL2, basis2)
    measb2 = project_traceout!(sacrificedR2, basis2)

    success1 = measa1 == measb1
    success2 = measa2 == measb2

    if !(success1 && success2)
        traceout!(purifiedL)
        traceout!(purifiedR)
    end
    (success1 && success2)
end

"""
$TYPEDEF

Fields:

$FIELDS

A purification circuit sacrificing 2 Bell qubits to produce another.
The circuit is parameterized by a `leaveout1`, and a `leaveout2` symbol argument
which specifies the leaveout of each of the two purification subcircuits
This purificaiton circuit is capable of detecting all errors.

This circuit returns the array of measurements made.

This circuit is the same as the Purifiy3to1 one but it works on individual qubits
(i.e. only one qubit of a pair)

This algorithm is detailed in [keisuke2009doubleselection](@cite)

```jldoctest
julia> a = Register(2)
       b = Register(2)
       c = Register(2)
       initalize!(a[1:2], bell)
       initalize!(b[1:2], bell)
       initalize!(c[1:2], bell)


julia> Purify3to1Node(:Z, :Y)(a[1], b[1], c[1]) == Purify3to1Node(:X)(a[2], b[2], c[2])
false
```
"""
struct Purify3to1Node <: AbstractCircuit
    """The error to be fixed twice"""
    leaveout1::Symbol
    leaveout2::Symbol
    function Purify3to1Node(leaveout1, leaveout2)
        if leaveout1 ∉ (:X, :Y, :Z) && leaveout2 ∉ (:X, :Y, :Z)
            throw(ArgumentError(lazy"""
            `Purify3to1` can represent one of three purification circuits (see its docstring),
            parameterized by the argument `leaveout1` and `leaveout2` which has to be one of `:X`, `:Y`, or `:Z`.
            You have instead chosen `$(repr(leaveout1))`, `$(repr(leaveout1))` which is not a valid option.
            Investigate where you are creating a purification circuit of type `Purify3to1`
            and ensure you are passing a valid argument.
            """))
        else
            new(leaveout1, leaveout2)
        end
    end
end

inputqubits(circuit::Purify3to1Node) = 3

function (circuit::Purify3to1Node)(purified,sacrificed1,sacrificed2)
    dictionary_measurement = Dict(:X => σˣ, :Y => σʸ, :Z => σᶻ)
    if circuit.leaveout1 != :Y || circuit.leaveout2 != :X
        dictionary_gate = Dict(:X => CNOT, :Y => ZCY, :Z => XCZ)
    else
        dictionary_gate = Dict(:X => CNOT, :Y => XCY, :Z => XCZ)
    end
    gate1, gate2, basis1, basis2 = dictionary_gate[circuit.leaveout1], dictionary_gate[circuit.leaveout2], dictionary_measurement[circuit.leaveout1], dictionary_measurement[circuit.leaveout2]

    apply!((sacrificed1, purified),gate1)
    apply!((sacrificed2, sacrificed1),gate2)
    measa1 = project_traceout!(sacrificed1, basis1)
    measa2 = project_traceout!(sacrificed2, basis2)

    (measa1, measa2)
end

function coin(basis, pair::Array, parity=0)
    measa = project_traceout!(pair[1], basis)
    measb = project_traceout!(pair[2], basis)
    success = (measa ⊻ measb == parity)
    success
end

function coinnode(basis, pair::Array, parity=0)
    measa = project_traceout!(pair[1], basis)
    measa
end

"""
$TYPEDEF

Fields:

$FIELDS

The STRINGENT-HEAD purification circuit.
The first part of the STRINGENT and EXPEDIENT circuit.
It has one parameter, that determines the first gate which is used.
"""
struct StringentHead <: AbstractCircuit
    """A symbol determining whether ZCZ or XCZ should be used as a gate"""
    type::Symbol
    function StringentHead(type)
        if type ∉ (:X, :Z)
            throw(ArgumentError(lazy"""
            `type` has to be one of `:X`, or `:Z`.
            You have instead chosen `$(repr(type))` which is not a valid option.
            Investigate where you are creating a purification circuit of type `StringentHead`
            and ensure you are passing a valid argument.
            """))
        else
            new(type)
        end
    end
end

inputqubits(circuit::StringentHead) = 6

function (circuit::StringentHead)(purifiedL, purifiedR, sacrificed...)
    if length(sacrificed) != 4
        throw(ArgumentError(lazy"""
            Function hasn't got the right number of arguments.
            """))
    end
    sacrificedL = [sacrificed[1:2]...]
    sacrificedR = [sacrificed[3:4]...]
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

"""
$TYPEDEF

Fields:

$FIELDS

The STRINGENT-HEAD purification circuit, on one qubit of a pair of 2.
The first part of the STRINGENT and EXPEDIENT circuit.
It has one parameter, that determines the first gate which is used.
It returns the array of measurements made by the circuit.

This algorithm is detailed in [naomi2013topological](@cite)
"""
struct StringentHeadNode <: AbstractCircuit
    type::Symbol
    function StringentHeadNode(type)
        if type ∉ (:X, :Z)
            throw(ArgumentError(lazy"""
            `type` has to be one of `:X`, or `:Z`.
            You have instead chosen `$(repr(type))` which is not a valid option.
            Investigate where you are creating a purification circuit of type `StringentHead`
            and ensure you are passing a valid argument.
            """))
        else
            new(type)
        end
    end
end

inputqubits(circuit::StringentHeadNode) = 3

function (circuit::StringentHeadNode)(purified, sacrificed...)

    if length(sacrificed) != 2
        throw(ArgumentError(lazy"""
            Function hasn't got the right number of arguments.
            """))
    end
    sacrificedarr = [sacrificed[1:2]...]

    gate, success = if circuit.type == :Z
        ZCZ, true
    else
        XCZ, true
    end
    apply!((purified, sacrificedarr[1]), gate)
    apply!((sacrificedarr[1], sacrificedarr[2]), ZCZ)

    alfa = coinnode(σˣ, [sacrificedarr[1]])
    beta = coinnode(σˣ, [sacrificedarr[2]])

    (alfa, beta)
end

"""
$TYPEDEF

Fields:

$FIELDS

The STRINGENT-BODY purification circuit.
The second part of the STRINGENT and EXPEDIENT circuit.
It has 2 parameters, one that determines the first gate which is used,
and the other one which determines if it is used
inside the STRINGENT or EXPEDIENT cicuits

This algorithm is detailed in [naomi2013topological](@cite)
"""
struct StringentBody <: AbstractCircuit
    """A symbol determining whether ZCZ or XCZ should be used as a gate"""
    type::Symbol
    """For EXPEDIENT circuits"""
    expedient::Bool
    function StringentBody(type, expedient=false)
        if type ∉ (:X, :Z)
            throw(ArgumentError(lazy"""
            `type` has to be one of `:X`, or `:Z`.
            You have instead chosen `$(repr(type))` which is not a valid option.
            Investigate where you are creating a purification circuit of type `StringentBody`
            and ensure you are passing a valid argument.
            """))
        else
            new(type, expedient)
        end
    end
end

inputqubits(circuit::StringentBody) = circuit.expedient ? 6 : 8

function (circuit::StringentBody)(purifiedL, purifiedR, sacrificed...)
    if length(sacrificed) != (circuit.expedient ? 6 : 8)
        throw(ArgumentError(lazy"""
            Function hasn't got the right number of arguments.
            """))
    end
    gate, success = if circuit.type == :Z
        ZCZ, true
    else
        XCZ, true
    end
    ## Indices for emulating pair creation
    i1 = 1
    i2 = 1

    sacrificedL = circuit.expedient ? [sacrificed[1:3]...] : [sacrificed[1:4]...]
    sacrificedR = circuit.expedient ? [sacrificed[4:6]...] : [sacrificed[5:8]...]
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

The STRINGENT-BODY purification circuit, on one qubit of a pair of 2.
The second part of the STRINGENT and EXPEDIENT circuit.
It has 2 parameters, one that determines the first gate which is used,
and the other one which determines if it is used
inside the STRINGENT or EXPEDIENT cicuits
It returns the array of measurements made by the circuits.

This algorithm is detailed in [naomi2013topological](@cite)
"""
struct StringentBodyNode <: AbstractCircuit
    type::Symbol
    expedient::Bool
    function StringentBodyNode(type, expedient=false)
        if type ∉ (:X, :Z)
            throw(ArgumentError(lazy"""
            `type` has to be one of `:X`, or `:Z`.
            You have instead chosen `$(repr(type))` which is not a valid option.
            Investigate where you are creating a purification circuit of type `StringentBody`
            and ensure you are passing a valid argument.
            """))
        else
            new(type, expedient)
        end
    end
end

inputqubits(circuit::StringentBodyNode) = circuit.expedient ? 3 : 4

function (circuit::StringentBodyNode)(purified, sacrificed...)
    if length(sacrificed) != (circuit.expedient ? 3 : 4)
        throw(ArgumentError(lazy"""
            Function hasn't got the right number of arguments.
            """))
    end

    gate, success = if circuit.type == :Z
        ZCZ, true
    else
        XCZ, true
    end
    ## Indices for emulating pair creation
    i1 = 1
    i2 = 1
    sacrificed1 = sacrificed[1:1]
    sacrificed2 = circuit.expedient ? [sacrificed[2:3]...] : [sacrificed[2:4]...]

    apply!((sacrificed1[i1], sacrificed2[i2]), XCZ)
    alfa = coinnode(σˣ, [sacrificed2[i2]])
    i2 = i2 + 1

    apply!((sacrificed1[i1], sacrificed2[i2]), ZCZ)
    beta = coinnode(σˣ, [sacrificed2[i2]])
    apply!((purified, sacrificed1[i1]), gate)

    if !circuit.expedient
        i2 = i2 + 1
        apply!((sacrificed1[i1], sacrificed2[i2]), ZCZ)
        gamma = coinnode(σˣ, [sacrificed2[i2]])
    end
    delta = coinnode(σˣ, [sacrificed1[i1]])
    (alfa)
end


"""
$TYPEDEF

Fields:

$FIELDS

The STRINGENT purification circuit.
It is composed of a head and a body.
The head is repeated twice and the body is also repeating twice

This algorithm is detailed in [krastanov2019optimised](@cite)

If an error was detected, the circuit returns `false` and the state is reset.
If no error was detected, the circuit returns `true`.

This algorithm is detailed in [naomi2013topological](@cite)

The sacrificial qubits are removed from the register.

```jldoctest
julia> r = Register(26, rep())
    for i in 1:13
        initialize!(r[(2*i-1):(2*i)], bell)
    end

julia> PurifyStringent()(r[1], r[2], r[3:2:25], r[4:2:26])
    true

```
"""
struct PurifyStringent <: AbstractCircuit
end

inputqubits(circuit::PurifyStringent) = 26

function (circuit::PurifyStringent)(purifiedL,purifiedR,sacrificed...)
    if length(sacrificed) != 24
        throw(ArgumentError(lazy"""
            Function hasn't got the right number of arguments.
            """))
    end

    success = true
    stringentHead_Z = StringentHead(:Z)
    stringentHead_X = StringentHead(:X)
    stringentBody_Z = StringentBody(:Z)
    stringentBody_X = StringentBody(:X)

    sacrificedL = [sacrificed[1:12]...]
    sacrificedR = [sacrificed[13:24]...]

    success = success & stringentHead_Z(purifiedL, purifiedR, sacrificedL[1:2]..., sacrificedR[1:2]...)
    success = success & stringentHead_X(purifiedL, purifiedR, sacrificedL[3:4]..., sacrificedR[3:4]...)
    success = success & stringentBody_Z(purifiedL, purifiedR, sacrificedL[5:8]..., sacrificedR[5:8]...)
    success = success & stringentBody_X(purifiedL, purifiedR, sacrificedL[9:12]..., sacrificedR[9:12]...)

    success
end




"""
$TYPEDEF

Fields:

$FIELDS

The EXPEDIENT purification circuit.
It is composed of a head and a body.
The head is repeated twice and the body is also repeating twice
The difference between it and the STRINGENT circuit is that the body is a bit modified.

If an error was detected, the circuit returns `false` and the state is reset.
If no error was detected, the circuit returns `true`.

This algorithm is detailed in [naomi2013topological](@cite)

The sacrificial qubits are removed from the register.

```jldoctest
julia> r = Register(22, rep())
    for i in 1:11
        initialize!(r[(2*i-1):(2*i)], bell)
    end

julia> PurifyExpedient()(r[1], r[2], r[3:2:21], r[4:2:22])
    true

```
"""
struct PurifyExpedient <: AbstractCircuit
end

inputqubits(circuit::PurifyExpedient) = 22

function (circuit::PurifyExpedient)(purifiedL,purifiedR,sacrificed...)
    if length(sacrificed) != 20
        throw(ArgumentError(lazy"""
            Function hasn't got the right number of arguments.
            """))
    end
    success = true
    stringentHead_Z = StringentHead(:Z)
    stringentHead_X = StringentHead(:X)
    stringentBody_Z = StringentBody(:Z, true)

    sacrificedL = [sacrificed[1:10]...]
    sacrificedR = [sacrificed[11:20]...]

    success = success & stringentHead_Z(purifiedL, purifiedR, sacrificedL[1:2]..., sacrificedR[1:2]...)
    success = success & stringentHead_X(purifiedL, purifiedR, sacrificedL[3:4]..., sacrificedR[3:4]...)
    success = success & stringentBody_Z(purifiedL, purifiedR, sacrificedL[5:7]..., sacrificedR[5:7]...)
    success = success & stringentBody_Z(purifiedL, purifiedR, sacrificedL[8:10]..., sacrificedR[8:10]...)

    success
end


"""
$TYPEDEF

Fields:

$FIELDS

The STRINGENT purification circuit ( on a single qubit of a pair ).
It is composed of a head and a body.
The head is repeated twice and the body is also repeating twice

This returns the array of measurements made by the circuit.

This algorithm is detailed in [naomi2013topological](@cite)

```jldoctest
julia> r = Register(26, rep())
    for i in 1:13
        initialize!(r[(2*i-1):(2*i)], bell)
    end

julia> PurifyStringentNode()(r[1], r[3:2:25]) == PurifyStringentNode()(r[2], r[4:2:26])
    true

```
"""
struct PurifyStringentNode <: AbstractCircuit
end

inputqubits(circuit::PurifyStringentNode) = 13

function (circuit::PurifyStringentNode)(purified,sacrificed...)
    if length(sacrificed) != 12
        throw(ArgumentError(lazy"""
            Function hasn't got the right number of arguments.
            """))
    end
    success = true
    stringentHead_Z = StringentHeadNode(:Z)
    stringentHead_X = StringentHeadNode(:X)
    stringentBody_Z = StringentBodyNode(:Z)
    stringentBody_X = StringentBodyNode(:X)

    a = stringentHead_Z(purified, sacrificed[1:2]...)
    b = stringentHead_X(purified, sacrificed[3:4]...)
    c = stringentBody_Z(purified, sacrificed[5:8]...)
    d = stringentBody_X(purified, sacrificed[9:12]...)
    [a..., b..., c..., d...]
end

"""
$TYPEDEF

Fields:

$FIELDS

The EXPEDIENT purification circuit ( on a single qubit of a pair ).
It is composed of a head and a body.
The head is repeated twice and the body is also repeating twice

This returns the array of measurements made by the circuit.

This algorithm is detailed in [naomi2013topological](@cite)

```jldoctest
julia> r = Register(22, rep())
    for i in 1:11
        initialize!(r[(2*i-1):(2*i)], bell)
    end

julia> PurifyExpedientNode()(r[1], r[3:2:21]) == PurifyExpedientNode()(r[2], r[4:2:22])
    true

```
"""
struct PurifyExpedientNode <: AbstractCircuit
end

inputqubits(circuit::PurifyExpedientNode) = 11

function (circuit::PurifyExpedientNode)(purified,sacrificed...)
    if length(sacrificed) != 10
        throw(ArgumentError(lazy"""
            Function hasn't got the right number of arguments.
            """))
    end
    success = true
    stringentHead_Z = StringentHeadNode(:Z)
    stringentHead_X = StringentHeadNode(:X)
    stringentBody_Z = StringentBodyNode(:Z, true)

    a = stringentHead_Z(purified, sacrificed[1:2]...)
    b = stringentHead_X(purified, sacrificed[3:4]...)
    c = stringentBody_Z(purified, sacrificed[5:7]...)
    d = stringentBody_Z(purified, sacrificed[8:10]...)

    [a..., b..., c..., d...]
end

end # module
