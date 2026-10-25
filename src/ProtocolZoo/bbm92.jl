module ProtocolZoo

using QuantumSavory
import QuantumSavory: get_time_tracker, Tag, isolderthan, onchange, QueryOnRegResult
import QuantumSavory: _message_type
using QuantumSavory: Wildcard, alwaystrue, compactstr, @domain
using QuantumSavory.CircuitZoo: EntanglementSwap, LocalEntanglementSwap

using DocStringExtensions

using Distributions: Geometric
using ConcurrentSim: Simulation, @yield, timeout, @process, now
import ConcurrentSim: Process
import ResumableFunctions
using ResumableFunctions: @resumable
import SumTypes
using PrettyTables: PrettyTables, pretty_table

export BBM92Prot

@kwdef struct BBM92Prot <: AbstractProtocol
    sim::Simulation
    net::RegisterNet
    node::Int
    partner::Int
    basis_prob::Float64 = 0.5
    sifting_fraction::Float64 = 0.1
    qber_threshold::Float64 = 0.15
    rounds::Int = -1
end

protocol_catalog_metadata(::Type{BBM92Prot}) = (
    attachment = :node,
    attachment_fields = (node=:node,),
    required_fields = (:partner,),
)

@resumable function (prot::BBM92Prot)()
    reg = prot.net[prot.node]
    partner_reg = prot.net[prot.partner]
    mb = messagebuffer(prot.net, prot.node)
    round = 1

    while prot.rounds != 0
        # Measure in random basis
        slot = findfreeslot(reg; randomize=true, locked=false)
        if isnothing(slot)
            @yield onchange(reg, Tag)
            continue
        end

        basis = rand(prot.sim.rng) < prot.basis_prob ? :Z : :X
        apply!(slot, basis == :Z ? Z : H)

        # Compare bases with partner
        msg = send_query(prot.sim, prot.partner, slot.idx, basis)
        if msg.basis != basis
            continue
        end

        # Collect matching basis measurements
        sifting = rand(prot.sim.rng) < prot.sifting_fraction
        if sifting
            key_bit = measure!(slot)
            store!(slot, :key_bit, key_bit)
        end

        # Periodically estimate QBER
        if round % 100 == 0
            qber = estimate_qber(partner_reg)
            if qber > prot.qber_threshold
                @error "QBER exceeds threshold: $qber"
            end
        end

        round += 1
        prot.rounds == -1 || (prot.rounds -= 1)
    end
end

function estimate_qber(reg::Register)
    errors = 0
    total = 0
    for slot in reg
        if haskey(slot.metadata, :key_bit)
            # Simulated error detection
            errors += rand(slot.sim.rng) < 0.01 ? 1 : 0
            total += 1
        end
    end
    return total == 0 ? 0.0 : errors / total
end

end