If you already know the condition you care about, prefer the waiting helpers:

- `query_wait(...)` for “wait until a matching tag exists”;
- `querydelete_wait!(...)` for “wait until a matching tag or message exists and
  consume it”.

That is the documented default over:

- manual polling loops; or
- `@yield onchange(...)` followed by a separate `query(...)`.

Why these helpers are preferred:

- they query first and only wait if needed;
- they give the same high-level behavior on `Register` and `MessageBuffer`;
- they express the protocol intent directly.

Example for register metadata:

```julia
result = @yield query_wait(reg, :ready, W)
```

Example for a consumable message:

```julia
msg = @yield querydelete_wait!(messagebuffer(net, 2), :swap_request)
```

Use `querydelete!` or `querydelete_wait!` when the state is consumable. That is
usually the right choice for classical messages.

Use `onchange(...)` only when you genuinely want a more open-ended “something
changed” wait and will inspect the state afterward.

Two related caveats from `.agents`:

- `queryall` is register-only, not for message buffers;
- if resource availability matters, add `locked=` or `assigned=` filters rather
  than matching on tags alone.

