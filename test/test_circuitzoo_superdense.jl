using QuantumSavory
using QuantumSavory.CircuitZoo: SDEncode, SDDecode
using Test

## Set up an entangled bell pair
ra = Register(1)
rb = Register(1)

initialize!(ra[1], Z1)
initialize!(rb[1], Z1)

apply!(ra[1], H)
apply!((ra[1], rb[1]), CNOT)

# Random 2 bit classical message
message = Tuple(rand(0:1, 2))

# Use the circuits to encode and decode the message
SDEncode()(ra, message)
rec = SDDecode()(ra, rb)

@test message == rec
