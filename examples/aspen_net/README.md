# ASPEN-Net: two sources and one hub

Run `julia --project=examples examples/aspen_net/1_simple_run.jl` from the
repository root. This example uses the internal `ProtocolZoo.AspenNet` module;
its interface is experimental.

Two end nodes share a global clock and send photons to one hub. Each receives
one `Start(start_tick, stop_tick)` message with an integer-tick working interval.
A source keeps the first heralded
photon in each buffer period, then releases it at the agreed time. Its unbalanced
beam splitter distributes the photon between local memory and the quantum link.
Here, `reflectivity=0.1` sends 10% of the photon probability to the hub. Quantum
and classical links have equal delays.

Local number measurements immediately consume the memories. The hub erases path
information and records a threshold-detector success or failure for each period.
Missing inputs are vacuum; a single incoming photon can produce a success, and
two incoming photons can produce a false herald because the detectors do not
resolve photon number. Compare the internal `_log` histories by `period`;
local `t` is the release time and hub `t` includes the one-way delay. This example
does not retain an entangled memory pair after local measurement.

The text displays summarize each history. With `CairoMakie` loaded,
`display(MIME"image/png"(), hub)` renders the hub history as a plot.

```mermaid
flowchart TD
    Start[Wait for a Start message] --> Valid{Valid working interval?}
    Valid -->|No| Start
    Valid -->|Yes| Buffer[Wait for the next buffer release time]
    Buffer --> Photon{A first photon was heralded?}
    Photon -->|Yes| Split[Split between memory and quantum link]
    Split --> Local[Tag memory with release time]
    Local --> Measure[LocalMeasurement: measure number, remove tag, append history]
    Split --> Send[Send remote mode to the hub]
    Photon -->|No| Next{Another period in the interval?}
    Split --> Next
    Next -->|Yes| Buffer
    Next -->|No| Start
```

```mermaid
flowchart TD
    Tick[Wait for the period's arrival deadline] --> Receive[Collect the two source modes]
    Receive --> Erase[Erase path information in the joint measurement]
    Erase --> Detect[Measure with threshold detectors]
    Detect --> Log[Append success or failure to hub history]
    Log --> Announce[Send Confirmation tags to both end nodes]
    Announce --> Tick
```
