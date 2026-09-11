# Butterfly Network Coding Example

This example demonstrates quantum network coding on a 6-node butterfly topology. 
It compares classical routing (where the central link becomes a bottleneck when two senders transmit simultaneously) 
with a quantum network coding scheme that uses pre-shared entanglement and local parity measurements 
to deliver both states without bottlenecking.

## Files
- `setup.jl`: Defines the 6-node butterfly network topology, registers, and basic simulation processes (entangler, swapper, consumer).
- `1_interactive_visualization.jl`: GLMakie dashboard allowing users to run the simulation and toggle between classical routing and quantum coding modes.

## Running the example
```julia
julia --project=examples
julia> include("examples/butterflynetwork/1_interactive_visualization.jl")
```

## Testing
```julia
julia --project=test -e 'using Pkg; Pkg.instantiate(); include("test/examples/butterflynetwork_tests.jl")'
```
