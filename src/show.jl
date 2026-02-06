compactstr(val) = sprint(show, val; context = :compact => true)

timestr(t::Float64) = @sprintf "[%.6g]" t
timestr(s::Simulation) = timestr(now(s))
