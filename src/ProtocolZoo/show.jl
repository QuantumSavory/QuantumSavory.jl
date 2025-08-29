function Base.show(io::IO, m::MIME"text/html", p::AbstractProtocol)
    print(io,
    """
    <div class="quantumsavory_show quantumsavory_protocol quantumsavory_protocol_unknown">
    state of type <pre class="quantumsavory_typename quantumsavory_protocol_typename">$(typeof(p))</pre> does not support rich visualization in HTML
    </div>
    """)
end
