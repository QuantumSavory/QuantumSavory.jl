using Oxygen
using JSON3
using QuantumSavory
using QuantumSavory.StatesZoo
using QuantumSavory.StatesZoo.Genqo: GenqoUnheraldedSPDCBellPairW, GenqoMultiplexedCascadedBellPairW
using QuantumOpticsBase
using QuantumSymbolics

@oxidise
@get "/api/health" function()
    return Dict("status" => "healthy", "message" => "QuantumSavory StatesZoo API is running -- see implementation details at https://github.com/QuantumSavory/QuantumSavory.jl/tree/main/examples/states_rest_api")
end

# Barrett-Kok Bell Pair endpoints
@get "/api/barrett-kok/density-matrix" function(req)
    # Extract parameters with defaults
    ηᴬ = Base.get(queryparams(req), "etaA", "1.0") |> x -> parse(Float64, x)
    ηᴮ = Base.get(queryparams(req), "etaB", "1.0") |> x -> parse(Float64, x)
    Pᵈ = Base.get(queryparams(req), "Pd", "0.0") |> x -> parse(Float64, x)
    ηᵈ = Base.get(queryparams(req), "etad", "1.0") |> x -> parse(Float64, x)
    𝒱 = Base.get(queryparams(req), "V", "1.0") |> x -> parse(Float64, x)
    m = Base.get(queryparams(req), "m", "0") |> x -> parse(Int, x)
    weighted = Base.get(queryparams(req), "weighted", "false") == "true"

    try
        # Validate parameters
        if !(0 ≤ ηᴬ ≤ 1) || !(0 ≤ ηᴮ ≤ 1) || !(0 ≤ ηᵈ ≤ 1) || !(0 ≤ abs(𝒱) ≤ 1) || Pᵈ < 0
            return Dict("error" => "Invalid parameters: transmissivities must be in [0,1], Pd must be ≥0, |V| must be in [0,1]")
        end

        # Create the state
        if weighted
            state = BarrettKokBellPairW(ηᴬ, ηᴮ, Pᵈ, ηᵈ, 𝒱, m)
        else
            state = BarrettKokBellPair(ηᴬ, ηᴮ, Pᵈ, ηᵈ, 𝒱, m)
        end

        # Get density matrix
        ρ = express(state, QuantumOpticsRepr())
        density_matrix = Array(ρ.data)

        return Dict(
            "state_type" => weighted ? "BarrettKokBellPairW" : "BarrettKokBellPair",
            "parameters" => Dict(
                "etaA" => ηᴬ,
                "etaB" => ηᴮ,
                "Pd" => Pᵈ,
                "etad" => ηᵈ,
                "V" => 𝒱,
                "m" => m
            ),
            "density_matrix" => Dict(
                "real" => real.(density_matrix),
                "imag" => imag.(density_matrix)
            ),
            "trace" => real(tr(ρ)),
            "dimensions" => size(density_matrix)
        )
    catch e
        return Dict("error" => "Failed to compute density matrix: $(string(e))")
    end
end

@get "/api/barrett-kok/parameters" function()
    params = stateparameters(BarrettKokBellPair)
    ranges = stateparametersrange(BarrettKokBellPair)

    return Dict(
        "parameters" => params,
        "ranges" => ranges,
        "description" => Dict(
            "etaA" => "Individual channel transmissivity from source A to entanglement swapping station, ∈[0,1]",
            "etaB" => "Individual channel transmissivity from source B to entanglement swapping station, ∈[0,1]",
            "Pd" => "Total excess noise (photons per qubit slot) in photon detectors, ≥0, usually ≪1",
            "etad" => "Detection efficiency of photon detectors, ∈[0,1]",
            "V" => "Mode matching parameter for individual interacting photonic pulses, |V|∈[0,1]",
            "m" => "Parity bit determined by click pattern (0 or 1)"
        )
    )
end

# Genqo ZALM (Multiplexed Cascaded) endpoints
@get "/api/genqo/zalm/density-matrix" function(req)
    # Extract parameters with defaults
    ηᵇ = Base.get(queryparams(req), "etab", "1.0") |> x -> parse(Float64, x)
    ηᵈ = Base.get(queryparams(req), "etad", "1.0") |> x -> parse(Float64, x)
    ηᵗ = Base.get(queryparams(req), "etat", "1.0") |> x -> parse(Float64, x)
    N = Base.get(queryparams(req), "N", "0.1") |> x -> parse(Float64, x)
    Pᵈ = Base.get(queryparams(req), "Pd", "1e-8") |> x -> parse(Float64, x)

    try
        # Validate parameters
        if !(0 ≤ ηᵇ ≤ 1) || !(0 ≤ ηᵈ ≤ 1) || !(0 ≤ ηᵗ ≤ 1) || N ≤ 0 || Pᵈ < 0
            return Dict("error" => "Invalid parameters: transmissivities must be in [0,1], N must be >0, Pd must be ≥0")
        end

        # Create the state
        state = GenqoMultiplexedCascadedBellPairW(ηᵇ, ηᵈ, ηᵗ, N, Pᵈ)

        ρ = express(state, QuantumOpticsRepr())
        density_matrix = Array(ρ.data)

        return Dict(
            "state_type" => "GenqoMultiplexedCascadedBellPairW",
            "parameters" => Dict(
                "etab" => ηᵇ,
                "etad" => ηᵈ,
                "etat" => ηᵗ,
                "N" => N,
                "Pd" => Pᵈ
            ),
            "density_matrix" => Dict(
                "real" => real.(density_matrix),
                "imag" => imag.(density_matrix)
            ),
            "trace" => real(tr(ρ)),
            "dimensions" => size(density_matrix)
        )
    catch e
        return Dict("error" => "Failed to compute density matrix: $(string(e))")
    end
end

@get "/api/genqo/zalm/parameters" function()
    params = stateparameters(GenqoMultiplexedCascadedBellPairW)
    ranges = stateparametersrange(GenqoMultiplexedCascadedBellPairW)

    return Dict(
        "parameters" => params,
        "ranges" => ranges,
        "description" => Dict(
            "etab" => "Loss (transmissivity) in the Bell state measurement at the source, ∈[0,1]",
            "etad" => "Loss (transmissivity) in all of the detectors, ∈[0,1]",
            "etat" => "Outcoupling transmissivity for the bell-state modes, ∈[0,1]",
            "N" => "Mean photon number per mode of the state (tradeoff for fidelity vs rate), >0",
            "Pd" => "Excess noise (photons per qubit slot) in photon detectors, ≥0"
        )
    )
end

# Genqo SPDC endpoints
@get "/api/genqo/spdc/density-matrix" function(req)
    # Extract parameters with defaults
    ηᵈ = Base.get(queryparams(req), "etad", "1.0") |> x -> parse(Float64, x)
    ηᵗ = Base.get(queryparams(req), "etat", "1.0") |> x -> parse(Float64, x)
    N = Base.get(queryparams(req), "N", "0.1") |> x -> parse(Float64, x)
    Pᵈ = Base.get(queryparams(req), "Pd", "1e-6") |> x -> parse(Float64, x)

    try
        # Validate parameters
        if !(0 ≤ ηᵈ ≤ 1) || !(0 ≤ ηᵗ ≤ 1) || N ≤ 0 || Pᵈ < 0
            return Dict("error" => "Invalid parameters: transmissivities must be in [0,1], N must be >0, Pd must be ≥0")
        end

        # Create the state
        state = GenqoUnheraldedSPDCBellPairW(ηᵈ, ηᵗ, N, Pᵈ)

        ρ = express(state, QuantumOpticsRepr())
        density_matrix = Array(ρ.data)

        return Dict(
            "state_type" => "GenqoUnheraldedSPDCBellPairW",
            "parameters" => Dict(
                "etad" => ηᵈ,
                "etat" => ηᵗ,
                "N" => N,
                "Pd" => Pᵈ
            ),
            "density_matrix" => Dict(
                "real" => real.(density_matrix),
                "imag" => imag.(density_matrix)
            ),
            "trace" => real(tr(density_matrix)),
            "dimensions" => size(density_matrix)
        )
    catch e
        return Dict("error" => "Failed to compute density matrix: $(string(e))")
    end
end

@get "/api/genqo/spdc/parameters" function()
    params = stateparameters(GenqoUnheraldedSPDCBellPairW)
    ranges = stateparametersrange(GenqoUnheraldedSPDCBellPairW)

    return Dict(
        "parameters" => params,
        "ranges" => ranges,
        "description" => Dict(
            "etad" => "Loss (transmissivity) in all of the detectors, ∈[0,1]",
            "etat" => "Outcoupling transmissivity for the bell-state modes, ∈[0,1]",
            "N" => "Mean photon number per mode of the state (tradeoff for fidelity vs rate), >0",
            "Pd" => "Excess noise (photons per qubit slot) in photon detectors, ≥0"
        )
    )
end

# General info endpoint
@get "/api/states" function()
    return Dict(
        "available_states" => [
            Dict(
                "name" => "BarrettKokBellPair",
                "description" => "Normalized Barrett-Kok Bell pair state",
                "endpoint" => "/api/barrett-kok/density-matrix",
                "parameters_endpoint" => "/api/barrett-kok/parameters"
            ),
            Dict(
                "name" => "BarrettKokBellPairW",
                "description" => "Weighted Barrett-Kok Bell pair state (trace = success probability)",
                "endpoint" => "/api/barrett-kok/density-matrix?weighted=true",
                "parameters_endpoint" => "/api/barrett-kok/parameters"
            ),
            Dict(
                "name" => "GenqoMultiplexedCascadedBellPairW",
                "description" => "Heralded multiplexed cascaded source (ZALM)",
                "endpoint" => "/api/genqo/zalm/density-matrix",
                "parameters_endpoint" => "/api/genqo/zalm/parameters"
            ),
            Dict(
                "name" => "GenqoUnheraldedSPDCBellPairW",
                "description" => "Unheralded SPDC Bell pair source",
                "endpoint" => "/api/genqo/spdc/density-matrix",
                "parameters_endpoint" => "/api/genqo/spdc/parameters"
            )
        ]
    )
end

# Start the server
if abspath(PROGRAM_FILE) == @__FILE__
    println("Starting QuantumSavory StatesZoo API server...")
    println("Available endpoints:")
    println("  GET /api/health - Health check")
    println("  GET /api/states - List available quantum states")
    println("  GET /api/barrett-kok/density-matrix - Barrett-Kok Bell pair density matrix")
    println("  GET /api/barrett-kok/parameters - Barrett-Kok parameters info")
    println("  GET /api/genqo/zalm/density-matrix - Genqo ZALM density matrix")
    println("  GET /api/genqo/zalm/parameters - Genqo ZALM parameters info")
    println("  GET /api/genqo/spdc/density-matrix - Genqo SPDC density matrix")
    println("  GET /api/genqo/spdc/parameters - Genqo SPDC parameters info")

    port = parse(Int, Base.get(ENV, "QS_STATES_REST_SERVER_PORT", "8080"))
    host = Base.get(ENV, "QS_STATES_REST_SERVER_IP", "127.0.0.1")
    external_url = Base.get(ENV, "QS_STATES_REST_SERVER_PROXY", nothing)
    external_url = Base.get(ENV, "QS_STATES_REST_SERVER_PROXY", nothing)
    docs_path = Base.get(ENV, "QS_STATES_REST_SERVER_DOCPATH", "/docs")
    serve(;port, host, external_url, docs_path)
end
