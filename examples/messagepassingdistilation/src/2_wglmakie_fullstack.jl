using Base.Threads
using WGLMakie
WGLMakie.activate!()
using JSServe
using Markdown

using CSSMakieLayout
include("setup.jl")
include("cssconfig.jl")
import JSServe.TailwindDashboard as D

"""
    Dictionary that assigns an integer identifier to each type of
    purificaiton circuit. Used when one of the two circuits is selected
    to be used by the free qubit trigger protocol.
"""
purifcircuit = Dict(
    2=>Purify2to1Node,
    3=>Purify3to1Node
)

"""
    Dictionary that assigns a name to each identifier of a purificaiton
    circuit. Used when one of the two circuits is selected
    to be used by the free qubit trigger protocol.
"""
idof = Dict(
    "Single Selection"=>2,
    "Double Selection"=>3
)

"""
    Function that returns the left side of the layout, meaning the figures 
    from the menu and the main active figure.
"""
function layout_content(DOM, mainfigures
    , menufigures, title_zstack, active_index)
    
    menufigs_andtitles = wrap([
        vstack(
            hoverable(menufigures[i], anim=[:border], class="$(config[:colorscheme][2])";
                    stayactiveif=@lift($active_index == i)),
            title_zstack[i];
            class="justify-center align-center "  
            ) 
        for i in 1:length(mainfigures)]; class="menufigs", style=menufigs_style)
   
    unactive = [wrap(mainfigures[i]) for i in 2:length(mainfigures)]
    activefig = zstack(
                active(mainfigures[1]),
                unactive...;
                activeidx=active_index,
                anim=[:whoop],
                style="width: $(config[:resolution][1]/retina_scale)px")
    
    content = Dict(
        :activefig => activefig,
        :menufigs => menufigs_andtitles
    )
    return DOM.div(menufigs_andtitles, CSSMakieLayout.formatstyle, activefig, DOM.style(""".menufigs canvas {
        width: $(config[:smallresolution][1]/retina_scale)px !important;
        height: $(config[:smallresolution][2]/retina_scale)px !important;
    }""")), content

end

"""
    Plots the second figure in the layout with information about purification.

    On the left side, one can see the network with each entangled pair color
    coded for easier visualization, and on the center one can view the color scale 
    that is used.

    The right side has 2 sections: the sliders and the fidelity plots.
    There are two fidelity plots: one that plots the maximum fidelity among all pairs
    (the big one at the bottom), and one that keeps an inventory of the fidelities
    in the form of a histogram (small one at the top, near the sliders).

    The sliders are chosen to be representative for what the purification part does, and
    they are: *recycle purif pairs* and *register size*.

    - *recycle purif pairs* selects weather the already purified pairs can be used again
    for purification. The protocol handles this option optimally, by only allowing a generation
    of pairs to purify a pair of the same generation (we define a generation by the number of times
    a pair has been purified). This parameter defaults to false, but should be set to true if
    one wants to visualize a wider range of fidelities as they grow from generation to generation.
    
    - *register size* sets the register size (defaults to 6). Has been put in this figure to
    help the user increase/decrease the size of the register to make the using of bigger/smaller
    purification circuits viable.

    - *circuit*: can be either Double Selection or Simple Selection. When modifying it, one can
    see how Double Selection perfoms much better in terms of final vs initial fidelity.

    This function also handles the stopping/running events, which are used by both plots, and
    are facilitated by the **running** observable.
"""
function plot_alphafig(F, meta="",mfig=nothing, extrafig=nothing; hidedecor=false, observables=nothing)
    if isnothing(observables)
        return
    end
    running, obs_perform_purification, obs_time, obs_commtime, 
        obs_registersizes, obs_node_timedelay, obs_initial_prob,
        obs_purifcircuitid, obs_emitonpurifsuccess, webobs_logcontent, webobs_showlog, obs_sampledenttimes = observables

    perform_purification = obs_perform_purification[]
    time = obs_time[]
    commtimes = [obs_commtime[], obs_commtime[]]
    registersizes = [obs_registersizes[],obs_registersizes[]]
    node_timedelay = obs_node_timedelay[]
    initial_prob = obs_initial_prob[]
    purifcircuitid = obs_purifcircuitid[]         # id of circuit in use: 2 for singlesel, 3 for double sel
    noisy_pair = noisy_pair_func(initial_prob[])
    emitonpurifsuccess = obs_emitonpurifsuccess[]==1

    protocol = FreeQubitTriggerProtocolSimulation(
                purifcircuit[purifcircuitid];
                waittime=node_timedelay[1], busytime=node_timedelay[2],
                emitonpurifsuccess=emitonpurifsuccess
            )
    sim, network = simulation_setup(registersizes, commtimes, protocol)
    _,ax,p,obs = registernetplot_axis(F[1:2,1:3],network; twoqubitobservable=projector(StabilizerState("XX ZZ")))
    _,mfig_ax,mfig_p,mfig_obs = nothing, nothing, nothing, nothing
    _,extrafig_ax,extrafig_p,extrafig_obs = nothing, nothing, nothing, nothing
    (mfig !== nothing) && begin
        _,mfig_ax,mfig_p,mfig_obs = registernetplot_axis(mfig[1, 1],network; twoqubitobservable=projector(StabilizerState("XX ZZ"))) end
    (extrafig !==nothing) && begin
        _,extrafig_ax,extrafig_p,extrafig_obs = registernetplot_axis(extrafig[1:2,1:3],network; twoqubitobservable=projector(StabilizerState("XX ZZ"))) end
    hidedecor && return

    F[3, 1:6] = buttongrid = GridLayout(tellwidth = false)
    buttongrid[1,1] = b = Makie.Button(F, label = @lift($running ? "Stop" : "Run"), fontsize=32)
    leftfig = F[1:2, 1:3]
    rightfig = F[1:2, 4:6]
    
    Colorbar(leftfig[1:2, 3], limits = (0, 1), colormap = :Spectral,
                flipaxis = false)
    plotfig = rightfig[2,1:4]
    fidax = Axis(plotfig, title="Maximum Entanglement Fidelity")
    sfigtext = rightfig[1,1]
    textax = Axis(sfigtext)
    hidespines!(textax, :t, :r)

    subfig = rightfig[1, 2:4]
    sg = SliderGrid(subfig[1, 1],
        (label="recycle purif pairs", range=0:1, startvalue=0),
        (label="register size", range=3:10, startvalue=6))
    observable_params = [obs_emitonpurifsuccess, obs_registersizes]
    m = Menu(subfig[2, 1], options = ["Single Selection", "Double Selection"], prompt="Purification circuit...", default="Double Selection")
    on(m.selection) do sel
        obs_purifcircuitid[] = idof[sel]
        notify(obs_purifcircuitid)
    end

    for i in 1:length(observable_params)
        on(sg.sliders[i].value) do val
            if !running[]
                observable_params[i][] = val
                notify(observable_params[i])
            end
        end
    end

    on(b.clicks) do _ 
        running[] = !running[]
    end

    on(running) do r
        if r
            webobs_logcontent[] = ""
            perform_purification = obs_perform_purification[]
            time = obs_time[]
            commtimes = [obs_commtime[], obs_commtime[]]
            registersizes = [obs_registersizes[], obs_registersizes[]]
            node_timedelay = obs_node_timedelay[]
            initial_prob = obs_initial_prob[]
            purifcircuitid = obs_purifcircuitid[]
            noisy_pair = noisy_pair_func(initial_prob[])
            emitonpurifsuccess = obs_emitonpurifsuccess[]==1
            obs_sampledenttimes[] = [-1.0]
            protocol = FreeQubitTriggerProtocolSimulation(
                purifcircuit[purifcircuitid];
                waittime=node_timedelay[1], busytime=node_timedelay[2],
                emitonpurifsuccess=emitonpurifsuccess
            )

            empty!(ax)
            sim, network = simulation_setup(registersizes, commtimes, protocol)
            _,ax,p,obs = registernetplot_axis(F[1:2,1:3],network; twoqubitobservable=projector(StabilizerState("XX ZZ")))
            if mfig !== nothing
                empty!(mfig_ax)
                _,mfig_ax,mfig_p,mfig_obs = registernetplot_axis(mfig[1, 1],network; twoqubitobservable=projector(StabilizerState("XX ZZ")))
            end
            if extrafig !== nothing
                empty!(extrafig_ax)
                _,extrafig_ax,extrafig_p,extrafig_obs = registernetplot_axis(extrafig[1:2,1:3],network; twoqubitobservable=projector(StabilizerState("XX ZZ")))
            end
            
            currenttime = Observable(0.0)
            # Setting up the ENTANGMELENT protocol
            for (;src, dst) in edges(network)
                @process freequbit_trigger(sim, protocol, network, src, dst, webobs_showlog[] ? webobs_logcontent : nothing)
                @process entangle(sim, protocol, network, src, dst, noisy_pair, webobs_showlog[] ? webobs_logcontent : nothing, [obs_sampledenttimes])
                @process entangle(sim, protocol, network, dst, src, noisy_pair, webobs_showlog[] ? webobs_logcontent : nothing, [obs_sampledenttimes])
            end
            # Setting up the purification protocol 
            if perform_purification
                for (;src, dst) in edges(network)
                    @process purifier(sim, protocol, network, src, dst, webobs_showlog[] ? webobs_logcontent : nothing)
                    @process purifier(sim, protocol, network, dst, src, webobs_showlog[] ? webobs_logcontent : nothing)
                end
            end
            # Plotting time on x axis and max fidelity on y axis
            coordsx = Float32[]
            maxcoordsy= Float32[]
            for t in 0:0.1:time
                currenttime[] = t
                run(sim, t)
                notify(obs)
                notify(mfig_obs)
                notify(extrafig_obs)
                notify(obs_sampledenttimes)
                ax.title = "t=$(t)"
                if !running[]
                    break
                end
                if length(p[:fids][]) > 0
                    empty!(textax)
                    hist!(textax, p[:fids][], direction=:x, color=1, colormap=:tab10, colorrange = (1, 10))
                    push!(coordsx, t)
                    push!(maxcoordsy, maximum(p[:fids][]))
                    empty!(fidax)
                    stairs!(fidax, coordsx, maxcoordsy, color=1, linewidth=3, colormap=:tab10, colorrange = (1, 10))
                end
            end
        end
    end
end

"""
    Plots the first figure with information about entanglement generation.

    On the left side, one can see the network with each entangled pair color
    coded for easier visualization, and on the right one can view the sliders and
    a plot showing the entanglement generation time sampled from an exponential 
    distribution.

    An **exponential distribution** is used usually for predicting time until an
    event occurs, which in our case is the entangled pair generation.

    When an entangled pair is generated it's sampled generation time is plotted on the
    right side of the figure.

    The sliders are chosen to be the most important parameters of the entanglement 
    generation part of the protocol: *time*, *initial fidelity*, *channel delay*.

    - *time*: the time in which the simultation runs. Use it to increase/decrease the
    duration of the simulation. The more time, the higher the maximum fidelity will get.

    - *initial fidelity*: the initial fidelity used for the initialization of the pairs
    as a probabilistic object with F probability to be a clear state, and 1-F probability
    to be a mixed state. Has been put here to help the user see how the purification protocol
    and ciruits perform starting from a wider range of probabilities.

    - *chanel delay*: as the communication happens through channels it is mandatory that
    the protocol imposes a time delay between the sender and the receiver of a message.
    The *channel delay* parameter is exactly that, and it's modification will only affect
    the run time of the simulation, and perhaps the positions of the pairs being entangled.
"""
function plot_betafig(F, meta="",mfig=nothing; hidedecor=false, observables=nothing)
    running, obs_perform_purification, obs_time, obs_commtime, 
        obs_registersizes, obs_node_timedelay, obs_initial_prob,
        obs_purifcircuitid, obs_emitonpurifsuccess, webobs_logcontent, webobs_showlog, obs_sampledenttimes = observables
    rightfig = F[1:2, 4:6]
    plotfig = rightfig[2,1:4]
    waittimeax = Axis(plotfig, title="Entanglement generation wait time", limits = (0, 5, 0, 2))
    mfig_waittimeax = nothing
    (mfig!==nothing) && (mfig_waittimeax = Axis(mfig[1,1], limits = (0, 5, 0, 2)))

    subfig = rightfig[1, 2:4]
    sg = SliderGrid(subfig[1, 1],
        (label="time", range=3:0.1:30, startvalue=20.3),
        (label="initial fidelity", range=0.5:0.1:0.9, startvalue=0.7),
        (label="chanel delay", range=0.1:0.1:0.3, startvalue=0.1))
    observable_params = [obs_time, obs_initial_prob, obs_commtime]
    F[3, 1:6] = buttongrid = GridLayout(tellwidth = false)
    buttongrid[1,1] = b = Makie.Button(F, label = @lift($running ? "Stop" : "Run"), fontsize=32)

    for i in 1:length(observable_params)
        on(sg.sliders[i].value) do val
            if !running[]
                observable_params[i][] = val
                notify(observable_params[i])
            end
        end
    end
    
    distr = Exponential(0.4)
    range = 0.05:0.1:4.95
    axes = [waittimeax]
    mfig!==nothing && (push!(axes, mfig_waittimeax))
    for axis in axes
        lines!(axis, range, 1/0.4 * exp.(-(collect(range) ./ 0.4)))
    end
    on(b.clicks) do _ 
        running[] = !running[]
        if running[] == true
            (empty!(axis) for axis in axes)
        end
    end
    for axis in axes
        lines!(axis, range, 1/0.4 * exp.(-(collect(range) ./ 0.4)))
        hist!(axis, obs_sampledenttimes)
    end
    
end

"""
    This function is used to plot both the purification and entanglement figures.
"""
function plot(figure_array, menufigs=[], metas=["", "", ""]; hidedecor=false, observables=nothing)
    plot_betafig(figure_array[1], metas[1], menufigs[1]; observables=observables)
    plot_alphafig(figure_array[2], metas[2], menufigs[2], figure_array[1]; hidedecor=hidedecor, observables=observables)
end

"""
    Landing Page of the app.

    This is the part of the program that handles the interactive part of the simulation.
    It uses CSSMakieLayout.jl for web layouting, and the above plot functions for the figures,
    as well as the setup.jl file for running the simulation.

    We use a big number of observables to make the layout as reactive as possible for the user
    to enjoy and learn from it.

    The observables split into two categories:
        - parameters of the simulation (which can be also found in 1_entangler_purifier_console.jl)
        - toggles and logs for the web part
    
    First we have the params of the simulation:
        
        - obs_perform_purification: weather purification should be performed (set to true)
        - obs_time: duration of the simulation
        - obs_commtime: channel time delay 
        - obs_registersizes: size of each register
        - obs_node_timedelay: [wait time, busy time], set to [0.4, 0.3]
        - obs_initial_prob: inital fidelity
        - obs_purifcircuitid: what circuit to use, based on the dictionaries above, 2 for SingleSelection (2to1)
                            and 3 for DoubleSelection (3to1)
        - obs_emitonpurifsuccess: if true the protocol will recycle purified pairs, elst it will not.
        - and obs_sampledenttimes: time intervals sampled by the entangled pair generation based on an exponantial
                                ditribution
    
    And then the web toggles and logs that are used to toggle logs, log interactions, or for the log itself.
        
        - webobs_logcontent: the content of the log
        - webobs_showlog: weather the log is enabled or not
        - webobs_editlog: weather log interactions are enabled or not
    
    The log enable/disable can be used to slightly imporve the run time of the simulation, although
    in some cases it might not seem like it improves the run time that much. It is kept (and defaulted to false)
    just in case one adds to this simulation, and time improvement becomes noticeable.

    The edit log enable/disable button is present because in some cases one might like to see what happened
    to a certain slot in a certain register as the simulation ran. When enabling this option, one can click a
    line from the log, and only all other events that involve the slots present in the clicked line will be 
    displayed. To go back to the full log, one should click the edit log buttin again to disable it.

    figurescount (set to 2), can be changed to 3 or more, if one wants to add more figures with some
    more information to the fullstack simulation. As we only handle entanglement generation and purification
    in this example, we kept it to 2, but as in the future, swapping and more could be added,
    the figurescount can be increased.
"""
landing = App() do session::Session
    figurescount = 2
    running = Observable(false)
    obs_perform_purification = Observable(true)
    obs_time = Observable(20.3)
    obs_commtime = Observable(0.1)
    obs_registersizes = Observable(6)
    obs_node_timedelay = Observable([0.4, 0.3])
    obs_initial_prob = Observable(0.7)
    obs_purifcircuitid = Observable(3)
    obs_emitonpurifsuccess = Observable(0)
    webobs_logcontent = Observable("--")
    webobs_showlog = Observable(false)
    obs_sampledenttimes = Observable([-1.0])
    allobs = [running, obs_perform_purification, obs_time, obs_commtime, 
                obs_registersizes, obs_node_timedelay, obs_initial_prob,
                obs_purifcircuitid, obs_emitonpurifsuccess, webobs_logcontent, webobs_showlog, obs_sampledenttimes]
    # Create the menufigures and the mainfigures
    mainfigures = [Figure(backgroundcolor=:white,  resolution=config[:resolution]) for _ in 1:figurescount]
    menufigures = [Figure(backgroundcolor=:white,  resolution=config[:smallresolution]) for i in 1:figurescount]
    titles= ["Entanglement Generation",
    "Entanglement Purification",
    "-"]
    activeidx = Observable(1)
    hoveredidx = Observable(0)

    for i in 1:figurescount
        on(events(menufigures[i]).mousebutton) do event
            activeidx[]=i  
            notify(activeidx)
        end
        on(events(menufigures[i]).mouseposition) do event
            hoveredidx[]=i  
            notify(hoveredidx)
        end
    end

    # Using the aforementioned plot function to plot for each figure array
    plot(mainfigures, menufigures, observables=allobs)
    
    # Create ZStacks displayong titles below the menu graphs
    titles_zstack = [zstack(wrap(DOM.h4(titles[i], class="upper")),
                            wrap(""); 
                            activeidx=@lift(($hoveredidx == i || $activeidx == i)),
                            anim=[:opacity], style="""color: $(config[:colorscheme][2]);""") for i in 1:figurescount]

    # Obtain reactive layout of the figures
    layout, content = layout_content(DOM, mainfigures, menufigures, titles_zstack, activeidx)
    # Add the logs + webobs_editlog option (clicking on a line and seeing only the log lines connecting to and from it)
    webobs_editlog = Observable(false)
    webobs_editlogbtn = DOM.div(modifier("✎", parameter=webobs_editlog, class="nostyle"), class="backbutton",
                                style=@lift(($webobs_editlog==true ? "border: 2px solid #d62828 !important;" : "border: 2px solid rgb(11, 42, 64);")))
    logs = [hstack(webobs_editlogbtn, vstack("Log...", @lift($webobs_showlog ? "[Enabled]" : "[Disabled]"), tie(webobs_logcontent), class="log_wrapper"))]
    about_sections = [hstack(
                        DOM.span(@lift($obs_purifcircuitid==2 ? "Single Selection" : "Double Selection")),
                        " | Register size: ",DOM.span(obs_registersizes)
                        ;style="color: $(config[:colorscheme][3]) !important; padding: 5px; background-color: white;")]
    # Add the back and log buttons
    backbutton = wrap(DOM.a("←", href="/"; style="width: 40px; height: 40px;"); class="backbutton")
    logbutton = wrap(modifier(DOM.span("📜"), parameter=webobs_showlog, class="nostyle"); class="backbutton")
    btns = vstack(backbutton, logbutton)
    # Info about the log: enabled/disabled
    loginfo = DOM.h4(@lift($webobs_showlog ? "Log Enabled" : "Log Disabled"); style="color: white;")
    # Add title to the right in the form of a ZStack
    titles_div = [vstack(hstack(DOM.h1(titles[i]), btns)) for i in 1:figurescount]
    titles_div[1] = active(titles_div[1])
    (titles_div[i] = wrap(titles_div[i]) for i in 2:figurescount) 
    titles_div = wrap(zstack(titles_div; activeidx=activeidx, anim=[:static]
    , style="""color: $(config[:colorscheme][4]);"""),
        about_sections[1], loginfo,
        zstack(active(logs[1]), wrap(logs[1]), activeidx=activeidx, anim=[:static])
    )

    # Add event listeners for when a log line is clicked
    onjs(session, webobs_editlog, js"""function on_update(new_value) {
        console.log(new_value)
        console_lines = document.querySelectorAll(".console_line.new")
        console_lines.forEach((line_deref, index, array) => {
            if (new_value == false) {
                array[index].classList.remove("hide")
                array[index].classList.add("unreactive")
            } else {
                array[index].classList.remove("unreactive")
                array[index].addEventListener("click", ()=>{
                    classes = array[index].className.split(' ')
                    if (classes.indexOf('unreactive') > -1) {return}
                    const index_cl = classes.indexOf('console_line');
                    if (index_cl > -1) {
                        classes.splice(index_cl, 1);
                    }
                    console_lines.forEach(elem=>{
                        elem.classList.remove("active")
                        elem.classList.add("hide")
                    })
                    array[index].classList.add("active")
                    classes.forEach(currclass=>{
                        console.log(currclass)
                        elemssharingclass = document.querySelectorAll("."+currclass)
                        if(currclass!="new" && currclass!="console_line" && currclass!="active") {
                            elemssharingclass.forEach(elem=>{
                                elem.classList.remove("hide")
                            })
                        }
                    })
                })
            }
        })
    }""")

    infodiv = wrap(
        DOM.div(@lift($webobs_showlog ? "Click on 📜 to disable log." : "Click on 📜 to enable log.")),
        DOM.div(@lift($webobs_editlog==false ? "Click on ✎ to select lines from log." : "Click on a line from the log to see all events related to it or, click on ✎ to show the full log again.")),
        class="infodiv"
    )
    return hstack(vstack(layout, infodiv), vstack(titles_div; style="padding: 20px; margin-left: 10px;
                                background-color: $(config[:colorscheme][3]);"), DOM.style(style); style="width: 100%;")

end



nav = App() do
    img1 = DOM.img(src="https://github.com/adrianariton/QuantumFristGenRepeater/blob/master/assets/entanglement_flow.png?raw=true"; style="height:30vw; width: fit-contentt;border-bottom: 2px solid black; margin: 5px;")
    img2 = DOM.img(src="https://github.com/adrianariton/QuantumFristGenRepeater/blob/master/assets/purification_flow.png?raw=true"; style="height:30vw; width: fit-contentt;border-bottom: 2px solid black margin: 5px; transform: translateX(-25px);")
    img3 = DOM.img(src="https://github.com/adrianariton/QuantumFristGenRepeater/blob/master/assets/purifperformance.png?raw=true"; style="height:30vw; width: fit-contentt;border-bottom: 2px solid black; margin: 5px;")

    list1 = DOM.ul(
        DOM.li("""initial fidelity: The Pauli noise for initial entanglement generation"""),
        DOM.li("""channel delay(s): The time it takes for a message to get from the sender to the receiver."""),
        DOM.li("""recycle purif pairs (also called `emitonpurifsuccess` in the code): If the protocol should use purified pairs reccurently to create even stronger ones (fidelity-wise)."""),
        DOM.li("""circuit: The purification circuit being used (can be 2 for **Single Selection** and 3 for **Double Selection**)"""),
    )
    list2 = DOM.ul(
        DOM.li("""The network graph (left side)"""),
        DOM.li("""The sliders (top right and top)"""),
        DOM.li("""Information about the current part of the protocol (right)"""),
    )
    text = [md"""
    # Entanglement generation in a network using delayed channels for communication
    
    Using this $(DOM.a("simulation", href="/1")), one can vizualize the processes happening in a network of nodes, as
    they communicate with eachother, requesting entanglement or purification of already entangled pairs.
    The simulation consists of 2 parts: entanglement generation and entanglement purification.

    The main goal of this simulation is to help in the understanding and visualization of the Free Qubit Trigger Protocol,
    with different parameters.

    ### About the Free Qubit Trigger Protocol
    
    The protocol consists of two steps: entanglement and purification. It has the following parameters:
    $(list1)
    
    The protocol can be split in two parts: **Entanglement Generation**, and **Purification**, both of which have their own figures in the simulation.
    In the 2 figures, one can modify the parameters specific to the targeted step of the protocol.

    The way they work can be visualized in the diagrams on the right.
    

    ### This $(DOM.a("simulation", href="/1")) consists of a layout containing the following components:
    $(list2)
    View the simulation $(DOM.a("here", href="/1"))!


    # Understanding the plots and the simulation
    
    ## Entanglement Generation

    The chronology of operations for the entanglegen process can be viewed in the first diagram.
    There is one single plot (on the left of the figure) other than the node graph. The plot plots the random
    amount of time it takes for an entangled pair to generate (when receiving **INITIALIZE_STATE**). The time is consistent with an exponential distribution.
    
    ## Purification
    
    The chronology of operations for the purification process can be viewed in the second diagram.
    We have 2 plots other than the node graph: a big one (bottom), and a smaller one (top, near the sliders).
    Both plots show information about fidelity. The big one plots the maxmimum fidelity among all pairs vs time,
    and the smaller one plots a histogram of all the pairs' fidelities.

    One can choose between two purification circuits: Double Selection (3to1) and Single Selection (2to1)
    Their performance is different, Double Selection resulting in a higher fidelity than Single Selection.

    One can view their performance in the following plot, which plots **final vs initial fidelity (blue)** and **success rate vs initial fidelity (yellow)**: 
    
    $(img3)
    
    (first column - variants of single selection, colums 2 to 4 - variants of double selection)


    """]
    return hstack(
        wrap(text; style="width:50vw;"), vstack(DOM.h2("Entanglement process flow"), img1, DOM.h2("Purifier process flow"), img2; style="width:50vw;", class="align-center justify-center"), CSSMakieLayout.formatstyle, DOM.style("""
            body {
                font-family: Arial;
            }
        """)
    )
end



# Serving the app.
isdefined(Main, :server) && close(server);
port = parse(Int, get(ENV, "QS_MESSAGEPASSINGDISTILATION_PORT", "8889"))
interface = get(ENV, "QS_MESSAGEPASSINGDISTILATION_IP", "127.0.0.1")
proxy_url = get(ENV, "QS_MESSAGEPASSINGDISTILATION_PROXY", "")
server = JSServe.Server(interface, port; proxy_url);
JSServe.HTTPServer.start(server)
JSServe.route!(server, "/" => nav);
JSServe.route!(server, "/1" => landing);

wait(server)