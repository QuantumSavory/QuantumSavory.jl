# QuantumSavory.jl

QuantumSavory.jl is a comprehensive framework implementing a vast array of simulation techniques for full-stack modeling of quantum hardware and quantum networks. It includes physical quantum dynamics, classical control, message passing, discrete event simulations, and quantum network protocols. The package is highly modular and integrates with the broader quantum software ecosystem.

Documentation is hosted at https://qs.quantumsavory.org/dev/

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

### Instantiate Environment
```bash
# Package
julia --project=. -e "using Pkg; Pkg.instantiate()"
```

### Running Tests
```bash
# Run default tests
julia --project=. -e "using Pkg; Pkg.test()"

# Run only JET tests
JET_TEST=true julia --project=. -e "using Pkg; Pkg.test()"

# Run all tests related to examples
QUANTUMSAVORY_EXAMPLES_TEST=true julia --project=. -e "using Pkg; Pkg.test()"

# Run all tests related to examples that also include plotting (notice the xvfb command necessary for having a graphical environment on headless servers)
QUANTUMSAVORY_EXAMPLES_PLOT_TEST=true DISPLAY=:0 xvfb-run -e /dev/null -s '-screen 0 1024x768x24' julia --project=. -e "using Pkg; Pkg.test()"

# Run all plotting tests (notice the xvfb command necessary for having a graphical environment on headless servers)
QUANTUMSAVORY_PLOT_TEST=true DISPLAY=:0 xvfb-run -e /dev/null -s '-screen 0 1024x768x24' julia --project=. -e "using Pkg; Pkg.test()"
```

Do not try to run single test files.

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

Do not read the Manifest.jl files -- they are machine generated and should not be manipulated directly.

## Key Dependencies

- `QuantumOptics.jl` - Quantum optics calculations and continuous variable systems
- `QuantumOpticsBase.jl` - Base quantum optics functionality
- `QuantumClifford.jl` - Stabilizer formalism and Clifford circuits
- `QuantumInterface.jl` - Common quantum computing interfaces
- `QuantumSymbolics.jl` - Symbolic quantum expressions
- `ConcurrentSim.jl` - Discrete event simulation
- `ResumableFunctions.jl` - Coroutine support for protocols
- `Graphs.jl` - Graph-based network modeling

## Visualization and Extensions

QuantumSavory.jl provides rich visualization capabilities through extensions:

- `QuantumSavoryMakie` - Interactive 2D/3D network visualization
- `QuantumSavoryTylerMakie` - Geographic network visualization
- `QuantumSavoryInteractiveUtils` - Introspection tools

Visualization features include:
- Real-time network state visualization
- Quantum state evolution tracking
- Protocol execution monitoring
- Network topology display

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

It is a good idea to keep two remotes - an `upstream` remote treated as a source of truth, and a personal `origin` remote on your own github account for storing branches and preparing pull requests. Pull requests can be managed with `gh`.

This package follows standard Julia development practices:
- **Always pull latest changes first**: Before creating any new feature or starting work, ensure you have the latest version by running `git pull upstream master` (or `git pull upstream main`)
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

## Creating Pull Requests

When creating pull requests to solve GitHub issues:

1. **Setup remotes properly**: Make sure you have both `origin` (your fork) and `upstream` (main repository) remotes configured:
   ```bash
   git remote add upstream https://github.com/QuantumSavory/QuantumSavory.jl.git
   git remote add origin https://github.com/YOUR_USERNAME/QuantumSavory.jl.git
   ```

2. **Create feature branch**: Always create a feature branch from the latest upstream master:
   ```bash
   git checkout master
   git pull upstream master
   git checkout -b descriptive-branch-name
   ```

3. **Make your changes**: Implement the solution, add tests, and ensure all tests pass:
   ```bash
   julia --project=. -e "using Pkg; Pkg.test()"
   ```

4. **Commit and push**: Commit your changes and push to your fork:
   ```bash
   git add .
   git commit -m "Descriptive commit message"
   git push -u origin your-branch-name
   ```

5. **Create PR using gh CLI**: Use the GitHub CLI to create the pull request:
   ```bash
   gh pr create --title "Your PR Title" --body "Description of changes" --repo QuantumSavory/QuantumSavory.jl
   ```

This workflow ensures your PR targets the main repository from your personal fork.
