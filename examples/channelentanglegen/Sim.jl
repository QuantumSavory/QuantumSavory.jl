using Base.Threads
using WGLMakie
WGLMakie.activate!()
using JSServe
using Markdown

# 1. LOAD LAYOUT HELPER FUNCTION AND UTILSm    
using CSSMakieLayout
include("setup.jl")
import JSServe.TailwindDashboard as D

## config sizes TODO: make linear w.r.t screen size
# Change between color schemes by uncommentinh lines 17-18
retina_scale = 2
config = Dict(
    :resolution => (retina_scale*1400, retina_scale*700), #used for the main figures
    :smallresolution => (280, 160), #used for the menufigures
    :colorscheme => ["rgb(242, 242, 247)", "black", "#000529", "white"]
    #:colorscheme => ["rgb(242, 242, 247)", "black", "rgb(242, 242, 247)", "black"]
)
# TODO all these need to be added as parameters to the plot function
obs_PURIFICATION = Observable(true)
obs_time = Observable(20.3)
obs_commtime = Observable(0.1)
obs_registersizes = Observable([6, 6])
obs_node_timedelay = Observable([0.4, 0.3])
obs_initial_prob = Observable(0.7)
obs_USE = Observable(3)
obs_emitonpurifsuccess = Observable(0)
logstring = Observable([DOM.span("Log:", id="console_line_0.0_1"), ])
logdiv = Observable([])
stamp = Observable(0.0)
showlog = true
purifcircuit = Dict(
    2=>purify2to1,
    3=>purify3to1
)


###################### 2. LAYOUT ######################
#   Returns the reactive (click events handled by zstack)
#   layout of the activefigure (mainfigure)
#   and menufigures (the small figures at the top which get
#   clicked)

function layout_content(DOM, mainfigures #TODO: remove DOM param
    , menufigures, title_zstack, session, active_index; keepsame=false)
    
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

###################### 3. PLOT FUNCTIONS ######################
#   These are used to configure each figure from the layout,
#   meaning both the menufigures and the mainfigures.
#   One can use either on whatever figure, but for the purpose
#   of this project, they will be used as such
#       |   plot_alphafig - for the first figure (Entanglement Generation)
#       |   plot_betafig - for the second figure (Entanglement Swapping)
#       |   plot_gammafig - for the third figure (Entanglement Purification)
#   , as one can see in the plot(figure_array, metas) function.


function plot_alphafig(F, meta="",mfig=nothing; hidedecor=false)
    PURIFICATION = obs_PURIFICATION[]
    time = obs_time[]
    commtimes = [obs_commtime[], obs_commtime[]]
    registersizes = obs_registersizes[]
    node_timedelay = obs_node_timedelay[]
    initial_prob = obs_initial_prob[]
    USE = obs_USE[]
    noisy_pair = noisy_pair_func(initial_prob[])
    emitonpurifsuccess = obs_emitonpurifsuccess[]==1
    old_params = []

    protocol = FreeQubitTriggerProtocolSimulation(USE, purifcircuit[USE], # purifcircuit
                                                node_timedelay[1], node_timedelay[2], # wait and busy times
                                                Dict(:simple_channel=>:channel,
                                                    :process_channel=>:process_channel), # keywords to store the 2 types of channels in the network
                                                emitonpurifsuccess, 10) # emit on purifsucess
    sim, network = simulation_setup(registersizes, commtimes, protocol)
    _,ax,p,obs = registernetplot_axis(F[1:2,1:3],network; color2qubitlinks=true)
    _,mfig_ax,mfig_p,mfig_obs = nothing, nothing, nothing, nothing
    (mfig !== nothing) && begin
        _,mfig_ax,mfig_p,mfig_obs = registernetplot_axis(mfig[1, 1],network; color2qubitlinks=true)
    end
    if hidedecor
        return
    end

    F[3, 1:6] = buttongrid = GridLayout(tellwidth = false)
    running = Observable(false)
    buttongrid[1,1] = b = Makie.Button(F, label = @lift($running ? "Stop" : "Run"), fontsize=32)

    Colorbar(F[1:2, 3:4], limits = (0, 1), colormap = :Spectral,
    flipaxis = false)

    plotfig = F[2,4:6]
    fidax = Axis(plotfig[2:24, 2:24], title="Maximum Entanglement Fidelity", titlesize=32)

    sfigtext = F[1,4]
    textax = Axis(sfigtext[1, 2:8])
    hidespines!(textax, :t, :r)

    subfig = F[1, 5:6]
    sg = SliderGrid(subfig,
    (label="time", range=3:0.1:30, startvalue=20.3),
    (label="circuit", range=2:3, startvalue=3),
    (label="1 - pauli error prob", range=0.5:0.1:0.9, startvalue=0.7),
    (label="chanel delay", range=0.1:0.1:0.3, startvalue=0.1),
    (label="recycle purif pairs", range=0:1, startvalue=0))
    observable_params = [obs_time, obs_USE, obs_initial_prob, obs_commtime, obs_emitonpurifsuccess]

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

    on(stamp) do stampval # adding stamps so one can see what the sim looked like at one point (still working on this feature)
        if !running[]
            sim, network, ax, mfig_ax, obs, mfig_obs = old_params[1], old_params[2], old_params[3], old_params[4], old_params[5], old_params[6]
            println("STAMPED $stampval")
            empty!(ax)
            run(sim, stampval)
            notify(obs)
            notify(mfig_obs)
        end
    end

    on(running) do r
        if r
            logstring[] = [DOM.span("Log:", id="console_line_0.0_1"), ]
            logdiv[] = []
            PURIFICATION = obs_PURIFICATION[]
            time = obs_time[]
            commtimes = [obs_commtime[], obs_commtime[]]
            registersizes = obs_registersizes[]
            node_timedelay = obs_node_timedelay[]
            initial_prob = obs_initial_prob[]
            USE = obs_USE[]
            noisy_pair = noisy_pair_func(initial_prob[])
            emitonpurifsuccess = obs_emitonpurifsuccess[]==1

            protocol = FreeQubitTriggerProtocolSimulation(USE, purifcircuit[USE], # purifcircuit
                                                        node_timedelay[1], node_timedelay[2], # wait and busy times
                                                        Dict(:simple_channel=>:channel,
                                                            :process_channel=>:process_channel), # keywords to store the 2 types of channels in the network
                                                        emitonpurifsuccess, 10) # emit on purif success
            sim, network = simulation_setup(registersizes, commtimes, protocol)
            _,ax,p,obs = registernetplot_axis(F[1:2,1:3],network; color2qubitlinks=true)
            if mfig !== nothing
                empty!(mfig_ax)
                _,mfig_ax,mfig_p,mfig_obs = registernetplot_axis(mfig[1, 1],network; color2qubitlinks=true)
            end
            
            currenttime = Observable(0.0)
            # Setting up the ENTANGMELENT protocol
            for (;src, dst) in edges(network)
                @process freequbit_trigger(sim, protocol, network, src, dst, showlog ? logstring : nothing)
                @process entangle(sim, protocol, network, src, dst, noisy_pair, showlog ? logstring : nothing)
                @process entangle(sim, protocol, network, dst, src, noisy_pair, showlog ? logstring : nothing)
            end
            # Setting up the purification protocol 
            if PURIFICATION
                for (;src, dst) in edges(network)
                    @process purifier(sim, protocol, network, src, dst, showlog ? logstring : nothing)
                    @process purifier(sim, protocol, network, dst, src, showlog ? logstring : nothing)
                end
            end

            coordsx = Float32[]
            maxcoordsy= Float32[]
            mincoordsy= Float32[]
            for t in 0:0.1:time
                currenttime[] = t
                run(sim, currenttime[])
                notify(obs)
                notify(mfig_obs)
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
        else
            old_params = (sim, network, ax, mfig_ax, obs, mfig_obs)
            empty!(ax)
            ax.title=nothing
            if mfig !== nothing
                empty!(mfig_ax)
                mfig_ax.title=nothing
            end
            
            #sim, network = simulation_setup(registersizes, commtimes, protocol)
            #_,ax,p,obs = registernetplot_axis(F[1:2,1:3],network; color2qubitlinks=true)
            if mfig !== nothing
                empty!(mfig_ax)
                _,mfig_ax,mfig_p,mfig_obs = registernetplot_axis(mfig[1, 1],network; color2qubitlinks=true)
            end
        end
    end
end

function plot_betafig(figure, meta=""; hidedecor=false)
    # This is where we will do the receipe for the second figure (Entanglement Swap)

    ax = Axis(figure[1, 1])
    scatter!(ax, [1,2], [2,3], color=(:black, 0.2))
    axx = Axis(figure[1, 2])
    scatter!(axx, [1,2], [2,3], color=(:black, 0.2))
    axxx = Axis(figure[2, 1:2])
    scatter!(axxx, [1,2], [2,3], color=(:black, 0.2))

    if hidedecor
        hidedecorations!(ax)
        hidedecorations!(axx)
        hidedecorations!(axxx)
    end
end

function plot_gammafig(figure, meta=""; hidedecor=false)
    # This is where we will do the receipe for the third figure (Entanglement Purif)

    ax = Axis(figure[1, 1])
    scatter!(ax, [1,2], [2,3], color=(:black, 0.2))

    if hidedecor
        hidedecorations!(ax)
    end
end

#   The plot function is used to prepare the receipe (plots) for
#   the mainfigures which get toggled by the identical figures in
#   the menu (the menufigures), as well as for the menufigures themselves

function plot(figure_array, menufigs=[], metas=["", "", ""]; hidedecor=false)
    if length(menufigs)==0
        with_theme(fontsize=32) do
            plot_alphafig(figure_array[1], metas[1]; hidedecor=hidedecor)
            plot_betafig( figure_array[2], metas[2]; hidedecor=hidedecor)
            plot_gammafig(figure_array[3], metas[3]; hidedecor=hidedecor)
        end
    else
        with_theme(fontsize=32) do
            plot_alphafig(figure_array[1], metas[1], menufigs[1]; hidedecor=hidedecor)
            plot_betafig( figure_array[2], metas[2]; hidedecor=hidedecor)
            plot_gammafig(figure_array[3], metas[3]; hidedecor=hidedecor)
        end
    end
end

###################### 4. LANDING PAGE OF THE APP ######################

landing = App() do session::Session
    keepsame=true
    # Create the menufigures and the mainfigures
    mainfigures = [Figure(backgroundcolor=:white,  resolution=config[:resolution]) for _ in 1:3]
    menufigures = [Figure(backgroundcolor=:white,  resolution=config[:smallresolution]) for i in 1:3]
    titles= ["Entanglement Generation",
    "Entanglement Swapping",
    "Entanglement Purification"]
    activeidx = Observable(1)
    hoveredidx = Observable(0)

    # CLICK EVENT LISTENERS
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
    plot(mainfigures, menufigures)
    
    # Create ZStacks displayong titles below the menu graphs
    titles_zstack = [zstack(wrap(DOM.h4(titles[i], class="upper")),
                            wrap(""); 
                            activeidx=@lift(($hoveredidx == i || $activeidx == i)),
                            anim=[:opacity], style="""color: $(config[:colorscheme][2]);""") for i in 1:3]

    # Obtain reactive layout of the figures
    layout, content = layout_content(DOM, mainfigures, menufigures, titles_zstack, session, activeidx)

    # Add title to the right in the form of a ZStack
    titles_div = [DOM.h1(t) for t in titles]
    titles_div[1] = active(titles_div[1])
    titles_div = zstack(titles_div; activeidx=activeidx, anim=[:static]
    , style="""color: $(config[:colorscheme][4]);""") # static = no animation

    if showlog
        on(logstring) do val
            el = val[end]
            # el = DOM.button(
            #     el,
            #     onclick=js"""event=> {
            #         $(stamp).notify(parseFloat($(el).id.split('_')[2]))
            #         console.log("TIME STAMP AT ", $(el).id.split('_')[2])
            #     }"""
            # ) # working on stamping feature
            push!(logdiv[], el)
            notify(logdiv)
        end
    end
    
    logwrap = wrap(logdiv, class="log_wrapper", style="
        max-height: 85vh !important; max-width: 90% !important; color: white; 
        display: flex;
        flex-direction: column-reverse;
        border-left: 2px solid rgb(38, 39, 41);
        border-bottom: 2px solid rgb(38, 39, 41);

        background-color: black;
        overflow: auto;
    ")
    print(logwrap)
    println(logstring)

    style = DOM.style("""
        .console_line:hover{
            background-color: rgba(38, 39, 41, 0.6);
        }
    """)


    return hstack(layout, vstack(titles_div, logwrap; style="padding: 20px; margin-left: 10px;
                                background-color: $(config[:colorscheme][3]);"), style; style="width: 100%;")

end


nav = App() do session::Session
    return vstack(DOM.a("LANDING", href="/1"))
end

##
# Serve the Makie app
isdefined(Main, :server) && close(server);
port = parse(Int, get(ENV, "QS_COLORCENTERMODCLUSTER_PORT", "8888"))
interface = get(ENV, "QS_COLORCENTERMODCLUSTER_IP", "127.0.0.1")
proxy_url = get(ENV, "QS_COLORCENTERMODCLUSTER_PROXY", "")
server = JSServe.Server(interface, port; proxy_url);
JSServe.HTTPServer.start(server)
JSServe.route!(server, "/" => nav);
JSServe.route!(server, "/1" => landing);

##

wait(server)