using HTTP
using JSON3

"""
Test script for the QuantumSavory StatesZoo REST API
"""

const BASE_URL = "http://localhost:8080"

function test_endpoint(endpoint, description)
    println("\n🧪 Testing: $description")
    println("📍 Endpoint: $endpoint")
    
    try
        response = HTTP.get("$BASE_URL$endpoint")
        if response.status == 200
            data = JSON3.read(String(response.body))
            println("✅ Success! Status: $(response.status)")
            
            # Pretty print some key information
            if haskey(data, "state_type")
                println("   State Type: $(data.state_type)")
            end
            if haskey(data, "trace")
                println("   Trace: $(data.trace)")
            end
            if haskey(data, "dimensions")
                println("   Matrix Dimensions: $(data.dimensions)")
            end
            if haskey(data, "parameters")
                println("   Parameters: $(length(data.parameters)) parameters")
            end
            if haskey(data, "available_states")
                println("   Available States: $(length(data.available_states)) states")
            end
            
            return true
        else
            println("❌ Failed! Status: $(response.status)")
            return false
        end
    catch e
        println("❌ Error: $e")
        return false
    end
end

function run_tests()
    println("🚀 Starting QuantumSavory StatesZoo API Tests")
    println("=" ^ 50)
    
    tests = [
        ("/api/health", "Health Check"),
        ("/api/states", "Available States List"),
        ("/api/barrett-kok/parameters", "Barrett-Kok Parameters"),
        ("/api/barrett-kok/density-matrix", "Barrett-Kok Density Matrix (default params)"),
        ("/api/barrett-kok/density-matrix?etaA=0.9&etaB=0.8&weighted=true", "Barrett-Kok Weighted (custom params)"),
        ("/api/genqo/zalm/parameters", "Genqo ZALM Parameters"),
        ("/api/genqo/spdc/parameters", "Genqo SPDC Parameters")
    ]
    
    # Note: We skip the genqo density matrix tests as they require the Python genqo package
    # which may not be installed in the test environment
    
    passed = 0
    total = length(tests)
    
    for (endpoint, description) in tests
        if test_endpoint(endpoint, description)
            passed += 1
        end
    end
    
    println("\n" * "=" ^ 50)
    println("📊 Test Results: $passed/$total tests passed")
    
    if passed == total
        println("🎉 All tests passed!")
    else
        println("⚠️  Some tests failed. Check the API server and try again.")
    end
end

# Run tests if this script is executed directly
if abspath(PROGRAM_FILE) == @__FILE__
    println("Note: Make sure the API server is running before running these tests!")
    println("Start the server with: julia api_server.jl")
    println("Then run this test script in another terminal.")
    println()
    
    # Give user a chance to start the server
    print("Press Enter when the server is ready (or Ctrl+C to cancel): ")
    readline()
    
    run_tests()
end