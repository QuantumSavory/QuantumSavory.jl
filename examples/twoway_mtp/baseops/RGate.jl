import QuantumSymbolics: Metadata

QuantumSymbolics.@withmetadata struct RGate <: QuantumSymbolics.AbstractSingleQubitGate
    dir::Symbol
    θ::Float64
end
QuantumSymbolics.symbollabel(g::RGate) = "R$(g.dir)($(g.θ))"
QuantumSymbolics.ishermitian(::RGate) = true
QuantumSymbolics.isunitary(::RGate) = true

QuantumSymbolics.express_nolookup(gate::RGate, ::QuantumSymbolics.QuantumOpticsRepr) = QuantumOptics.Operator(
    QuantumInterface.SpinBasis(1//2),
    if gate.dir == :x
        [cos(gate.θ/2) -im*sin(gate.θ/2); -im*sin(gate.θ/2) cos(gate.θ/2)]
    elseif gate.dir == :y
        [cos(gate.θ/2) -sin(gate.θ/2); sin(gate.θ/2) cos(gate.θ/2)]
    elseif gate.dir == :z
        [exp(-im*gate.θ/2) 0; 0 exp(im*gate.θ/2)]
    end
)


Rx(θ::Float64) = RGate(:x, θ)
Ry(θ::Float64) = RGate(:y, θ)
Rz(θ::Float64) = RGate(:z, θ)