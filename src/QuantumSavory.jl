module QuantumSavory

const glcnt = Ref{Int128}(0)

function guid()
    glcnt[] += 1
end

using Reexport

using DocStringExtensions
using IterTools
import LinearAlgebra
using LinearAlgebra: tr, mul!, eigvecs, norm, normalize, dot
import Random
using Random: randperm
using Graphs
import ConcurrentSim
using ConcurrentSim: Environment, Simulation, Store, DelayQueue, Resource,
      Process, @process,
      request, release, now, active_process, timeout, put, get
using ResumableFunctions
using Printf
import SumTypes
using SumTypes: @sum_type, isvariant, @cases
import Combinatorics
using Combinatorics: powerset

import QuantumInterface: basis, tensor, ⊗, apply!, traceout!, nsubsystems,
    AbstractOperator, AbstractKet, AbstractSuperOperator, Basis, SpinBasis

export apply!, traceout!, removebackref!, nsubsystems
export project_traceout! #TODO should move to QuantumInterface

using QuantumSymbolics:
    AbstractRepresentation, AbstractUse,
    CliffordRepr, consistent_representation, QuantumOpticsRepr, QuantumMCRepr,
    metadata, istree, operation, arguments, Symbolic, # from Symbolics
    HGate, XGate, YGate, ZGate, CPHASEGate, CNOTGate,
    XBasisState, YBasisState, ZBasisState,
    STensorOperator, SScaledOperator, SAddOperator
using QuantumSymbolics: I # to avoid ambiguity with LinearAlgebra.I
@reexport using QuantumSymbolics

export
    StateRef, RegRef, Register,
    Qubit, Qumode, QuantumStateTrait,
    CliffordRepr, QuantumOpticsRepr, QuantumMCRepr,
    UseAsState, UseAsObservable, UseAsOperation,
    AbstractBackground,
    onchange_tag,
    # networks.jl
    RegisterNet, channel, qchannel, messagebuffer,
    # initialize.jl
    initialize!, newstate,
    # subsystemcompose.jl
    subsystemcompose,
    # observable.jl
    observable,
    # uptotime.jl
    uptotime!, overwritetime!,
    # tags.jl and queries.jl
    Tag, tag!, untag!, W, ❓, query, queryall, querydelete!, findfreeslot,
    #messagebuffer.jl
    MessageBuffer,
    # quantumchannel.jl
    QuantumChannel,
    # backgrounds.jl
    T1Decay, T2Dephasing, Depolarization, PauliNoise, AmplitudeDamping,
    # noninstant.jl
    AbstractNoninstantOperation, NonInstantGate, ConstantHamiltonianEvolution,
    # plots.jl
    registernetplot, registernetplot!, registernetplot_axis, resourceplot_axis, generate_map


#TODO you can not assume you can always in-place modify a state. Have all these functions work on stateref, not stateref[]
# basically all ::QuantumOptics... should be turned into ::Ref{...}... but an abstract ref

# warnings for
function __init__()
    if isdefined(Base.Experimental, :register_error_hint)
        Base.Experimental.register_error_hint(MethodError) do io, exc, argtypes, kwargs
            if exc.f === registernetplot
                println(io, "\n`registernetplot!` requires the package `Makie`; please make sure `Makie` is installed and imported first.")
            elseif exc.f === registernetplot!
                println(io, "\n`registernetplot!` requires the package `Makie`; please make sure `Makie` is installed and imported first.")
            elseif exc.f === registernetplot_axis
                println(io, "\n`registernetplot_axis` requires the package `Makie`; please make sure `Makie` is installed and imported first.")
            elseif exc.f === resourceplot_axis
                println(io, "\n`resourceplot_axis` requires the package `Makie`; please make sure `Makie` is installed and imported first.")
            elseif exc.f === generate_map
                println(io, "\n`generate_map` requires the package `Tyler`; please make sure `Tyler` is installed and imported first.")
            end
        end
    end
end

include("traits_and_defaults.jl")

include("tags.jl")

include("semaphore.jl")

include("states_registers.jl")
include("quantumchannel.jl")
include("messagebuffer.jl")
include("networks.jl")
include("states_registers_networks_getset.jl")
include("states_registers_networks_shows.jl")

include("baseops/subsystemcompose.jl")
include("baseops/initialize.jl")
include("baseops/traceout.jl")
include("baseops/apply.jl")
include("baseops/uptotime.jl")
include("baseops/observable.jl")

include("queries.jl")

include("representations.jl")
include("backgrounds.jl")
include("noninstant.jl")

include("backends/quantumoptics/quantumoptics.jl")
include("backends/clifford/clifford.jl")

include("ambiguity_fix.jl")

include("concurrentsim.jl")

include("plots.jl")

include("CircuitZoo/CircuitZoo.jl")

include("StatesZoo/StatesZoo.jl")

include("ProtocolZoo/ProtocolZoo.jl")

include("precompile.jl")

end # module
