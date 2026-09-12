using Test
using Graphs
using QuantumSavory
using QuantumSavory.ProtocolZoo
using ConcurrentSim
using ResumableFunctions
using FileIO, CSV, HDF5

function simulation_setup(sizes::Vector{Int},T2::Float64;representation = QuantumOpticsRepr)
    R = length(sizes) 
    registers = Register[]

    for s in sizes
        traits = [Qubit() for _ in 1:s]
        repr = [representation() for _ in 1:s]
        bg = [T2Dephasing(T2) for _ in 1:s]
        push!(registers, Register(traits,repr,bg))
    end

    graph = grid([R])
    network = RegisterNet(graph, registers)

    sim = get_time_tracker(network)

    for v in vertices(network)
        network[v,:enttrackers] = Any[nothing for i in 1:sizes[v]]
    end

    sim, network
end

function noisy_pair_func(F)
    perfect_pair = StabilizerState("ZZ XX")
    perfect_pair_dm = SProjector(perfect_pair)
    mixed_dm = MixedState(perfect_pair_dm)

    return F*perfect_pair_dm + (1-F)*mixed_dm
end

const XX = X⊗X
const ZZ = Z⊗Z
const YY = Y⊗Y

@testset "EntanglementConsumer log saving" begin
    @testset "log is saved correctly to CSV and HDF5" begin
        sizes = zeros(Int,10) .+ 10
        T2 = 100.0
        F = 0.95
        entangler_wait_time = 0.1
        entangler_busy_time = 1.0

        sim, network = simulation_setup(sizes, T2)
        registers = [network[node] for node in vertices(network)]

        for (;src, dst) in edges(network)
            @process EntanglerProt(sim, network, src, dst, 
                pairstate = noisy_pair_func(F), 
                retry_lock_time = entangler_wait_time, 
                local_busy_time_post = entangler_busy_time, margin = 5)()
        end
        for node in vertices(network)
            if node > 1 || node < nv(network)
                @process SwapperProt(sim, network, node, 
                    nodeH = >(node), nodeL = <(node))()
            end
        end
        for node in vertices(network)
            @process EntanglementTracker(sim, network, node)()
        end
        
        consumer_prot = EntanglementConsumer(sim, network, 1, length(registers))
        @process consumer_prot()
        run(sim,100.0)

        csv_path = "entanglement_consumer_log.csv"
        hdf5_path = "entanglement_consumer_log.h5"

        metadata_dict = Dict(
            "sizes" => sizes,
            "T2" => T2,
            "F" => F,
            "entangler_wait_time" => entangler_wait_time,
            "entangler_busy_time" => entangler_busy_time,
            "description" => "Simulation of a quantum network with $(nv(network)) nodes and $(ne(network)) edges, using the specified parameters.",
            "simulator" => "QuantumSavory.jl",
            "reference_state" => "bell_pair",
            "log_format" => "pauli_observables"
        )

        metadata_namedtuple = NamedTuple(
            Symbol(k) => v for (k, v) in metadata_dict
        )

        function test_log_file_dict(file_path::String)
            save(file_path, consumer_prot; metadata = metadata_dict)
            return isfile(file_path) && filesize(file_path) > 0
        end

        function test_log_file_namedtuple(file_path::String)
            save(file_path, consumer_prot; metadata = metadata_namedtuple)
            return isfile(file_path) && filesize(file_path) > 0
        end

        function remove_log_file(file_path::String)
            if isfile(file_path)
                rm(file_path)
            end
        end

        # Test CSV saving
        @test test_log_file_dict(csv_path)
        @test test_log_file_namedtuple(csv_path)

        # Test HDF5 saving and loading
        @test test_log_file_dict(hdf5_path)
        @test EntanglementConsumerLog(hdf5_path) isa EntanglementConsumerLog
        @test test_log_file_namedtuple(hdf5_path)
        @test EntanglementConsumerLog(hdf5_path) isa EntanglementConsumerLog

        # Clean up test files
        remove_log_file(csv_path)
        remove_log_file(hdf5_path)
    end
end

