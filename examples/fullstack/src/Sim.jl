using Base.Threads
using WGLMakie
WGLMakie.activate!()
using JSServe
using Markdown

using CSSMakieLayout
include("setup.jl")
import JSServe.TailwindDashboard as D

retina_scale = 2
config = Dict(
    :resolution => (retina_scale*1400, retina_scale*700), #used for the main figures
    :smallresolution => (280, 160),                       #used for the menufigures
    :colorscheme => ["rgb(242, 242, 247)", "black", "#000529", "white"]
    # another color scheme: :colorscheme => ["rgb(242, 242, 247)", "black", "rgb(242, 242, 247)", "black"]
)

purifcircuit = Dict(
    2=>Purify2to1Node,
    3=>Purify3to1Node
)

function layout_content(DOM, mainfigures
    , menufigures, title_zstack, active_index; keepsame=false)
    
    menufigs_style = """
        display:flex;
        flex-direction: row;
        justify-content: space-around;
        background-color: $(config[:colorscheme][1]);
        padding-top: 20px;
        width: $(config[:resolution][1]/retina_scale)px;
    """
    menufigs_andtitles = wrap([
        vstack(
            hoverable(keepsame ? mainfigures[i] : menufigures[i], anim=[:border], class="$(config[:colorscheme][2])";
                    stayactiveif=@lift($active_index == i)),
            title_zstack[i];
            class="justify-center align-center "  
            ) 
        for i in 1:3]; class="menufigs", style=menufigs_style)
   
    activefig = zstack(
                active(mainfigures[1]),
                wrap(mainfigures[2]),
                wrap(mainfigures[3]);
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

idof = Dict(
    "Single Selection"=>2,
    "Double Selection"=>3
)

function plot_alphafig(F, meta="",mfig=nothing, extrafig=nothing; hidedecor=false, observables=nothing)
    if isnothing(observables)
        return
    end
    running, obs_PURIFICATION, obs_time, obs_commtime, 
        obs_registersizes, obs_node_timedelay, obs_initial_prob,
        obs_USE, obs_emitonpurifsuccess, logstring, showlog, obs_sampledenttimes = observables

    PURIFICATION = obs_PURIFICATION[]
    time = obs_time[]
    commtimes = [obs_commtime[], obs_commtime[]]
    registersizes = [obs_registersizes[],obs_registersizes[]]
    node_timedelay = obs_node_timedelay[]
    initial_prob = obs_initial_prob[]
    USE = obs_USE[]         # id of circuit in use: 2 for singlesel, 3 for double sel
    noisy_pair = noisy_pair_func(initial_prob[])
    emitonpurifsuccess = obs_emitonpurifsuccess[]==1

    protocol = FreeQubitTriggerProtocolSimulation(
                purifcircuit[USE];
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
        obs_USE[] = idof[sel]
        notify(obs_USE)
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
            logstring[] = ""
            PURIFICATION = obs_PURIFICATION[]
            time = obs_time[]
            commtimes = [obs_commtime[], obs_commtime[]]
            registersizes = [obs_registersizes[], obs_registersizes[]]
            node_timedelay = obs_node_timedelay[]
            initial_prob = obs_initial_prob[]
            USE = obs_USE[]
            noisy_pair = noisy_pair_func(initial_prob[])
            emitonpurifsuccess = obs_emitonpurifsuccess[]==1
            obs_sampledenttimes[] = [-1.0]
            protocol = FreeQubitTriggerProtocolSimulation(
                purifcircuit[USE];
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
                @process freequbit_trigger(sim, protocol, network, src, dst, showlog[] ? logstring : nothing)
                @process entangle(sim, protocol, network, src, dst, noisy_pair, showlog[] ? logstring : nothing, [obs_sampledenttimes])
                @process entangle(sim, protocol, network, dst, src, noisy_pair, showlog[] ? logstring : nothing, [obs_sampledenttimes])
            end
            # Setting up the purification protocol 
            if PURIFICATION
                for (;src, dst) in edges(network)
                    @process purifier(sim, protocol, network, src, dst, showlog[] ? logstring : nothing)
                    @process purifier(sim, protocol, network, dst, src, showlog[] ? logstring : nothing)
                end
            end

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
                    hist!(textax, p[:fids][], direction=:x, color=:blue)
                    push!(coordsx, t)
                    push!(maxcoordsy, maximum(p[:fids][]))
                    empty!(fidax)
                    stairs!(fidax, coordsx, maxcoordsy, color=(emitonpurifsuccess ? :blue : :green), linewidth=3)
                end
            end
        end
    end
    return running
end

function plot_betafig(F, meta="",mfig=nothing; hidedecor=false, observables=nothing)
    running, obs_PURIFICATION, obs_time, obs_commtime, 
        obs_registersizes, obs_node_timedelay, obs_initial_prob,
        obs_USE, obs_emitonpurifsuccess, logstring, showlog, obs_sampledenttimes = observables
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
        lines!(axis, range, 1/0.4 * exp.(-(collect(range) ./ 0.4)), color=:blue)
        hist!(axis, obs_sampledenttimes, color=:blue)
    end
    
end

function plot_gammafig(F, meta="",mfig=nothing; hidedecor=false, observables=nothing)
    
end

#   The plot function is used to prepare the receipe (plots) for
#   the mainfigures which get toggled by the identical figures in
#   the menu (the menufigures), as well as for the menufigures themselves

function plot(figure_array, menufigs=[], metas=["", "", ""]; hidedecor=false, observables=nothing)
    plot_alphafig(figure_array[2], metas[2], menufigs[2], figure_array[1]; hidedecor=hidedecor, observables=observables)
    plot_betafig(figure_array[1], metas[1], menufigs[1]; observables=observables)
end

###################### LANDING PAGE OF THE APP ######################

landing = App() do session::Session
    running = Observable(false)
    obs_PURIFICATION = Observable(true)
    obs_time = Observable(20.3)
    obs_commtime = Observable(0.1)
    obs_registersizes = Observable(6)
    obs_node_timedelay = Observable([0.4, 0.3])
    obs_initial_prob = Observable(0.7)
    obs_USE = Observable(3)
    obs_emitonpurifsuccess = Observable(0)
    logstring = Observable("")
    showlog = Observable(false)
    obs_sampledenttimes = Observable([-1.0])
    allobs = [running, obs_PURIFICATION, obs_time, obs_commtime, 
                obs_registersizes, obs_node_timedelay, obs_initial_prob,
                obs_USE, obs_emitonpurifsuccess, logstring, showlog, obs_sampledenttimes]
    keepsame=true
    # Create the menufigures and the mainfigures
    mainfigures = [Figure(backgroundcolor=:white,  resolution=config[:resolution]) for _ in 1:3]
    menufigures = [Figure(backgroundcolor=:white,  resolution=config[:smallresolution]) for i in 1:3]
    titles= ["Entanglement Generation",
    "Entanglement Swapping",
    "Entanglement Purification"]
    activeidx = Observable(1)
    hoveredidx = Observable(0)

    for i in 1:3
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
                            anim=[:opacity], style="""color: $(config[:colorscheme][2]);""") for i in 1:3]

    # Obtain reactive layout of the figures
    layout, content = layout_content(DOM, mainfigures, menufigures, titles_zstack, activeidx)
    # Add the logs + editlog option (clicking on a line and seeing only the log lines connecting to and from it)
    editlog = Observable(false)
    editlogbtn = DOM.div(modifier("✎", parameter=editlog, class="nostyle"), class="backbutton",
                                style=@lift(($editlog ? "border: 2px solid #d62828 !important;" : "border: 2px solid #003049;")))
    logs = [hstack(editlogbtn, vstack("Log...", @lift($showlog ? "[Enabled]" : "[Disabled]"), tie(logstring), class="log_wrapper"))]
    about_sections = [hstack(
                        DOM.span(@lift($obs_USE==2 ? "Single Selection" : "Double Selection")),
                        " | Register size: ",DOM.span(obs_registersizes)
                        ;style="color: $(config[:colorscheme][3]) !important; padding: 5px; background-color: white;")]
    # Add the back and log buttons
    backbutton = wrap(DOM.a("←", href="/"; style="width: 40px; height: 40px;"); class="backbutton")
    logbutton = wrap(modifier(DOM.span("📜"), parameter=showlog, class="nostyle"); class="backbutton")
    btns = vstack(backbutton, logbutton)
    # Info about the log: enabled/disabled
    loginfo = DOM.h4(@lift($showlog ? "Log Enabled" : "Log Disabled"); style="color: white;")
    # Add title to the right in the form of a ZStack
    titles_div = [vstack(hstack(DOM.h1(titles[i]), btns), about_sections[1], loginfo,
                            logs[1]) for i in 1:3]
    titles_div[1] = active(titles_div[1])
    (titles_div[i] = wrap(titles_div[i]) for i in 2:3) 
    titles_div = zstack(titles_div; activeidx=activeidx, anim=[:static]
    , style="""color: $(config[:colorscheme][4]);""") # static = no animation

    style = DOM.style("""
        .console_line:hover{
            background-color: rgba(38, 39, 41, 0.6);
            cursor: pointer;
        }
        .log_wrapper{
            max-height: 65vh !important; max-width: 90% !important; color: white; 
            display: flex;
            flex-direction: column-reverse;
            border-left: 2px solid rgb(38, 39, 41);
            border-bottom: 2px solid rgb(38, 39, 41);
            min-height: 40px !important;
            background-color: #003049;
            overflow: auto;
        }
        .backbutton{
            color: $(config[:colorscheme][4]) !important;
            background-color: white;
            padding: 10px;
            height: min-content;
        }

        .backbutton:hover{
            color: $(config[:colorscheme][4]) !important;
            opacity: 0.8;
        }

        .backbutton a{
            font-weight: bold;
        }
        .nostyle{
            border: none !important;
            padding: 0 0 0 0 !important;
            margin: 0 0 0 0 !important;
            background: transparent !important;
        }
        .hide{
            display: none;
        }
        .active {
            background-color: rgba(38, 39, 41, 0.8);
        }
        .infodiv{
            color: white;
            background-color: $(config[:colorscheme][3]);
            padding: 10px;
        }
    """)
    # console (log) lines script to select all that are related to a line
    onjs(session, editlog, js"""function on_update(new_value) {
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
        DOM.div(@lift($showlog ? "Click on 📜 to disable log." : "Click on 📜 to enable log.")),
        DOM.div(@lift($editlog==false ? "Click on ✎ to select lines from log." : "Click on a line from the log to see all events related to it or, click on ✎ to show the full log again.")),
        class="infodiv"
    )

    return hstack(vstack(layout, infodiv), vstack(titles_div; style="padding: 20px; margin-left: 10px;
                                background-color: $(config[:colorscheme][3]);"), style; style="width: 100%;")

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
        wrap(text; style="width:50vw;"), vstack(DOM.h2("Entanglement process flow"), img1, DOM.h2("Purifier process flow"), img2; style="width:50vw;", class="align-center justify-center"), CSSMakieLayout.formatstyle
    )
end


##
# Serve the Makie app
isdefined(Main, :server) && close(server);
port = parse(Int, get(ENV, "QS_COLORCENTERMODCLUSTER_PORT", "8889"))
interface = get(ENV, "QS_COLORCENTERMODCLUSTER_IP", "127.0.0.1")
proxy_url = get(ENV, "QS_COLORCENTERMODCLUSTER_PROXY", "")
server = JSServe.Server(interface, port; proxy_url);
JSServe.HTTPServer.start(server)
JSServe.route!(server, "/" => nav);
JSServe.route!(server, "/1" => landing);

##

wait(server)