# Include the already implemented code for first gen repeaters
include("setup.jl")

# We switch to tableau representation for our initial states.
# Converting from tableaux to kets or density matrices is cheap and automated,
# but the reverse direction is difficult. You can actually use the definition below
# for all types of simulations (tableau, ket, others).
const tableau = S"XX
                  ZZ"
const stab_perfect_pair = StabilizerState(tableau)
const stab_perfect_pair_dm = SProjector(stab_perfect_pair)
stab_noisy_pair_func(F) = F*stab_perfect_pair_dm + (1-F)*mixed_dm
