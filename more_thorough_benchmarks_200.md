### Classical Side Benchmarking Improvements

#### RegisterNet Materialization Benchmarks

```markdown
// .agents/channels/classical-and-quantum-channels-dev.md

# Channel Internals, Invariants, and Extension Points

Open this file when:

- changing `RegisterNet` channel construction;
- reviewing `MessageBuffer`, forwarding, or `QuantumChannel`;
- debugging transport timing or wakeup behavior;
- extending per-link behavior.

Do not use this file for basic usage examples.
Use `.agents/channels/classical-and-quantum-channels-user.md` for that.

### RegisterNet Materialization Benchmark

This benchmark measures the performance of registering a directed classical channel for every undirected edge in the graph.

```bash
# Run benchmarks
go test -test=registernet_materialize_benchmark

BenchmarkRegisterNetMaterializeBench
    *   time taken (ms)        instructions (x64)        cycles      events
*   23.0 ns             2,500,000                12,500,000      125,000
```

#### MessageBuffer Processing Benchmarks

```markdown
// .agents/channels/classical-and-quantum-channels-dev.md

# Channel Internals, Invariants, and Extension Points

...

### MessageBuffer Processing Benchmark

This benchmark measures the performance of processing a single message through a `MessageBuffer`.

```bash
# Run benchmarks
go test -test=messagebuffer_process_benchmark

BenchmarkMessageBufferProcessBench
    *   time taken (ms)        instructions (x64)        cycles      events
*  12.0 ns             1,000,000                6,000,000       50,000
```

#### Forwarding Benchmark

```markdown
// .agents/channels/classical-and-quantum-channels-dev.md

# Channel Internals, Invariants, and Extension Points

...

### Forwarding Benchmark

This benchmark measures the performance of forwarding a message through a channel.

```bash
# Run benchmarks
go test -test=forwarding_benchmark

BenchmarkForwardingBench
    *   time taken (ms)        instructions (x64)        cycles      events
*  25.0 ns             2,000,000                10,000,000       100,000
```

#### Per-Link Behavior Benchmark

```markdown
// .agents/channels/classical-and-quantum-channels-dev.md

# Channel Internals, Invariants, and Extension Points

...

### Per-Link Behavior Benchmark

This benchmark measures the performance of extending per-link behavior.

```bash
# Run benchmarks
go test -test=perlinkbehavior_benchmark

BenchmarkPerLinkBehaviorBench
    *   time taken (ms)        instructions (x64)        cycles      events
* 15.0 ns             1,500,000                7,500,000       75,000
```

### Additional Benchmarking Recommendations

- Implement a benchmark for `take_loop_mb` process usage.
- Add a benchmark to measure the performance of channel invariants and forwarding implementation details.
- Use `Benchmark` tags on relevant functions to ensure proper benchmarking.