# QuantumSavory.jl

QuantumSavory.jl is a comprehensive framework implementing a vast array of simulation techniques for full-stack modeling of quantum hardware and quantum networks. It includes physical quantum dynamics, classical control, message passing, discrete event simulations, and quantum network protocols. The package is highly modular and integrates with the broader quantum software ecosystem.

## Project Structure

- `src/` - Main source code
  - `QuantumSavory.jl` - Main module file
  - `CircuitZoo/` - Pre-defined quantum circuits and operations
  - `ProtocolZoo/` - Quantum networking protocols (entanglement swapping, purification, etc.)
  - `StatesZoo/` - Quantum state definitions and transformations
  - `backends/` - Different simulation backends
  - `baseops/` - Basic quantum operations (apply, initialize, observable, traceout)
  - `states_registers.jl` - Quantum state and register management
  - `networks.jl` - Quantum network modeling
  - `quantumchannel.jl` - Quantum communication channels
  - `concurrentsim.jl` - Discrete event simulation integration
  - `messagebuffer.jl` - Message passing for classical communication
  - `backgrounds.jl` - Background noise and decoherence
  - `noninstant.jl` - Non-instantaneous quantum operations
  - `queries.jl` - Quantum state queries and measurements
  - `tags.jl` - Quantum state tagging system
  - `plots.jl` - Visualization utilities
- `test/` - Comprehensive test suite covering all functionality
- `examples/` - Example applications and tutorials
- `docs/` - Documentation source
- `ext/` - Package extensions for interactive utilities and visualization
- `benchmark/` - Performance benchmarking

## Development Commands

### Running Tests
```bash
# Run all tests
julia --project=. -e "using Pkg; Pkg.test()"

# Run specific test files
julia --project=. test/test_register_interface.jl
julia --project=. test/test_protocolzoo_entangler.jl

# Run with specific backend tests
julia --project=. -e "using Pkg; Pkg.test(); include(\"test/test_noninstant_and_backgrounds_clifford.jl\")"
```

### Building Documentation
```bash
# Build documentation locally
julia --project=docs -e "using Pkg; Pkg.develop(PackageSpec(path=pwd())); Pkg.instantiate()"
julia --project=docs docs/make.jl
```

### Package Management
```bash
# Instantiate project dependencies
julia --project=. -e "using Pkg; Pkg.instantiate()"

# Update dependencies
julia --project=. -e "using Pkg; Pkg.update()"

# Check package status
julia --project=. -e "using Pkg; Pkg.status()"
```

### Running Examples
```bash
# Run specific examples
julia --project=examples examples/firstgenrepeater/1_entangler_example.jl
julia --project=examples examples/repeatergrid/1a_async_interactive_visualization.jl
```

### Benchmarking
```bash
# Run benchmarks
julia --project=benchmark benchmark/benchmarks.jl
```

## Testing Information

The test suite includes:

- Register and network interface tests
- Protocol zoo tests (entanglement protocols, swapping, purification)
- Circuit zoo tests (quantum circuits and gates)  
- States zoo tests (quantum state definitions)
- Background noise and non-instantaneous operation tests
- Quantum channel and message buffer tests
- Plotting and visualization tests
- Code quality tests (Aqua.jl, JET.jl)
- Documentation tests (DocTest)

Special test configurations:
- Tests run for different quantum backends (Clifford, continuous variable, etc.)
- Interactive visualization tests require display capabilities
- Some plotting tests require specific graphics backends

## Key Dependencies

- `QuantumOptics.jl` - Quantum optics calculations and continuous variable systems
- `QuantumOpticsBase.jl` - Base quantum optics functionality
- `QuantumClifford.jl` - Stabilizer formalism and Clifford circuits
- `QuantumInterface.jl` - Common quantum computing interfaces
- `QuantumSymbolics.jl` - Symbolic quantum expressions
- `ConcurrentSim.jl` - Discrete event simulation
- `ResumableFunctions.jl` - Coroutine support for protocols
- `Graphs.jl` - Graph-based network modeling
- `JuMP.jl` - Mathematical optimization for routing and resource allocation
- `HiGHS.jl` - High-performance linear programming solver

## Development Notes

- Minimum Julia version: 1.11
- Uses semantic versioning
- Extensive test coverage with CI on multiple platforms
- Documentation hosted at https://quantumsavory.github.io/QuantumSavory.jl/
- Supports multiple quantum simulation backends
- Interactive visualization through Makie.jl extensions
- Modular design allows selective use of components

## Visualization and Extensions

QuantumSavory.jl provides rich visualization capabilities through extensions:

- `QuantumSavoryMakie` - Interactive 2D/3D network visualization
- `QuantumSavoryTylerMakie` - Geographic network visualization
- `QuantumSavoryInteractiveUtils` - Interactive exploration tools

Visualization features include:
- Real-time network state visualization
- Quantum state evolution tracking
- Protocol execution monitoring
- Network topology display

## Related Packages

The QuantumSavory ecosystem includes several related packages:
- `QuantumOptics.jl` - Quantum optics simulations
- `QuantumOpticsBase.jl` - Base quantum optics types
- `QuantumClifford.jl` - Clifford circuit simulations
- `QuantumSymbolics.jl` - Symbolic quantum expressions
- `ConcurrentSim.jl` - Discrete event simulation
- `ResumableFunctions.jl` - Coroutine functionality
- `BPGates.jl` - Bell pair gate operations
- `LDPCDecoders.jl` - LDPC error correction decoders

## Code Formatting

### Removing Trailing Whitespaces
Before committing, ensure there are no trailing whitespaces in Julia files:

```bash
# Remove trailing whitespaces from all .jl files (requires gnu tools)
find . -type f -name '*.jl' -exec sed --in-place 's/[[:space:]]\+$//' {} \+
```

### Ensuring Files End with Newlines
Ensure all Julia files end with a newline to avoid misbehaving CLI tools:

```bash
# Add newline to end of all .jl files that don't have one
find . -type f -name '*.jl' -exec sed -i '$a\' {} \+
```

### General Formatting Guidelines
- Use 4 spaces for indentation (no tabs)
- Remove trailing whitespaces from all lines
- Ensure files end with a single newline
- Follow Julia standard naming conventions
- Keep lines under 100 characters when reasonable

## Contributing

This package follows standard Julia development practices:
- **Always pull latest changes first**: Before creating any new feature or starting work, ensure you have the latest version by running `git pull origin master` (or `git pull origin main`)
- **Pull before continuing work**: Other maintainers might have modified the branch you are working on. Always call `git pull` before continuing work on an existing branch
- **Push changes to remote**: Always push your local changes to the remote branch to keep the PR up to date: `git push origin <branch-name>`
- **Run all tests before submitting**: Before creating or updating a PR, always run the full test suite to ensure nothing is broken: `julia --project=. -e "using Pkg; Pkg.test()"`
- Fork and create feature branches
- Write tests for new functionality
- Ensure all tests pass before merging
- **Keep PRs focused**: A PR should implement one self-contained change. Avoid mixing feature work with formatting changes to unrelated files, even for improvements like adding missing newlines. Format unrelated files in separate commits or PRs.

## Multi-Package Development

When developing QuantumSavory.jl alongside related packages, use development mode for all dependencies:

```bash
# In your development environment
julia -e 'using Pkg; Pkg.develop(path="./QuantumOptics.jl")'
julia -e 'using Pkg; Pkg.develop(path="./QuantumOpticsBase.jl")'
julia -e 'using Pkg; Pkg.develop(path="./QuantumClifford.jl")'
julia -e 'using Pkg; Pkg.develop(path="./QuantumSavory.jl")'
```

This allows testing changes across multiple related packages simultaneously.