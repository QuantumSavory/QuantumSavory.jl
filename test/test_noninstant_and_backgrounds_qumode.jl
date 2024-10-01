@testitem "Noninstant and Backgrounds Qumode" tags=[:noninstant_and_backgrounds_qumode] begin

##
# Time of application and gate durations
reg = Register([Qumode(),Qubit(),Qumode()],[AmplitudeDamping(1.0),nothing,nothing])
initialize!(reg[1],F1)
initialize!(reg[2])
initialize!(reg[3],F1)
uptotime!(reg[1],0.2)
uptotime!(reg[1],0.2)
@test_throws ErrorException uptotime!(reg[1],0.1)
end
