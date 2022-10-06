include("setup.jl");

function run_until_connected(root_conf)
    net, sim, observables, conf = prep_sim(root_conf)
    # Run until all connections succeed
    while !all([net[v,:link_register] for v in edges(net)])
        SimJulia.step(sim)
    end
    # Calculate fidelity of each cluster node
    fid = map(vertices(net)) do v
        neighs = neighbors(net,v)
        obs = observables[length(neighs)]
        regs = [net[i, 2] for i in [v, neighs...]]
        real(observable(regs, obs; time=now(sim)))
    end
    now(sim), mean(fid)
end

@time run_until_connected(root_conf)
