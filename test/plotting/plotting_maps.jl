using Downloads
using FileIO
using Tyler
using QuantumSavory

const CI_TILE_TEMPLATE = "https://tiles.quantumsavory.org/styles/ci/{z}/{x}/{y}.png"
const CI_TILE_ATTRIBUTION =
    "Protomaps © OpenStreetMap contributors; hosted by QuantumSavory"

function ci_tile_provider()
    key = get(ENV, "TILE_CI_KEY", "")
    isempty(key) || occursin(r"\A[0-9a-f]{64}\z", key) ||
        throw(ArgumentError("TILE_CI_KEY must contain 64 lowercase hexadecimal characters"))
    url = isempty(key) ? CI_TILE_TEMPLATE : string(CI_TILE_TEMPLATE, "?ci_key=", key)
    return Tyler.TileProviders.Provider(
        url;
        max_zoom=13,
        attribution=CI_TILE_ATTRIBUTION,
    )
end

function verify_ci_tile(provider)
    mktemp() do path, io
        close(io)
        downloaded = try
            Downloads.download(Tyler.TileProviders.geturl(provider, 0, 0, 0), path)
            true
        catch
            false
        end
        downloaded || error("Could not download the QuantumSavory CI tile probe")
        open(path) do tile
            @test read(tile, 8) == UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
        end
    end
end

withenv("TILE_CI_KEY" => nothing) do
    @test Tyler.TileProviders.geturl(ci_tile_provider(), 0, 0, 0) ==
        "https://tiles.quantumsavory.org/styles/ci/0/0/0.png"
end
withenv("TILE_CI_KEY" => repeat("a", 64)) do
    @test Tyler.TileProviders.geturl(ci_tile_provider(), 0, 0, 0) ==
        "https://tiles.quantumsavory.org/styles/ci/0/0/0.png?ci_key=" * repeat("a", 64)
end
withenv("TILE_CI_KEY" => "invalid") do
    @test_throws ArgumentError ci_tile_provider()
end

provider = ci_tile_provider()
@test Tyler.TileProviders.max_zoom(provider) == 13
verify_ci_tile(provider)

sizes = [2,3,5]
registers = Register[]
for s in sizes
    traits = [Qubit() for _ in 1:s]
    bg = [T2Dephasing(1.0) for _ in 1:s]
    push!(registers, Register(traits,bg))
end
network = RegisterNet(registers)
fig, map_axis, map = generate_map(; provider)
@test map.provider === provider
coords = [Point2f(-71, 42), Point2f(-111, 34), Point2f(-122, 37)]
_, _, plt, netobs = registernetplot_axis(map_axis, network, registercoords=coords)
save(File{format"PNG"}(mktemp()[1]), fig)

initialize!(network[1,1])
initialize!(network[2,1])
notify(netobs)
save(File{format"PNG"}(mktemp()[1]), fig)

apply!([network[1,1],network[2,1]], CNOT)
notify(netobs)
save(File{format"PNG"}(mktemp()[1]), fig)

display(fig)
# Let Tyler finish throttled tile updates before shutting down map resources.
wait(map)
close(map)

fig = Figure()
fig, map_axis, map = generate_map(fig; provider)
@test map.provider === provider
_, _, plt, netobs = registernetplot_axis(map_axis, network, registercoords=coords)
save(File{format"PNG"}(mktemp()[1]), fig)
# Let Tyler finish throttled tile updates before shutting down map resources.
wait(map)
close(map)
