# Are We Entangled Yet?

This directory builds the complete [areweentangledyet.com](https://areweentangledyet.com/)
deployment as one container image. Caddy serves the landing page on port 8000 and
proxies HTTP and WebSocket traffic to seven Bonito applications and one Oxygen
API. The Julia services listen only on the container loopback interface.

The launcher waits for every service,
warms the Bonito applications with a private Playwright browser, and only then
starts public Caddy. If startup, Caddy, Xvfb, or any Julia process fails,
the launcher stops and reaps the remaining processes and returns a nonzero
status. A warmup failure is reported as a warning and startup continues.

## Requirements

- Docker with the Compose plugin
- Outbound HTTPS access to GitHub and the Julia package servers during builds
- At least 16 GiB of available memory and 16 logical CPU cores for concurrent
  startup and interactive use
- Additional disk space and time for the first build because the image contains
  two precompiled Julia environments and Chromium

Actual resource use depends on concurrent simulations. The default
backend startup deadline is 600 seconds; browser warmup adds several minutes.

## Local startup

From a committed and pushed checkout, build and start that exact revision:

```bash
QUANTUMSAVORY_REVISION="$(git rev-parse HEAD)" docker compose up --build
```

Open [http://localhost:8000](http://localhost:8000). Stop the foreground process
with `Ctrl-C`, or stop a detached deployment with:

```bash
docker compose down
```

The build uses `julia`, Caddy, Node,
Playwright Core, and Debian's Chromium package. It clones the complete
QuantumSavory.jl repository at `QUANTUMSAVORY_REVISION` (default `master`),
removes the Git history, and retains the tracked checkout in the image. It then
instantiates and precompiles both Julia environments. Container startup does not
clone a repository, download browser packages, or run `Pkg.resolve`,
`Pkg.update`, or any other package-network operation.

The builder reads source from GitHub, not from the local Docker build context.
Local changes must be committed and pushed before they can enter an image. An
exact commit SHA selects one checkout and invalidates the source layer cache.

## Production startup

Set `PUBLIC_URL` to the public HTTP origin. It must contain only a scheme, host,
and optional port. Do not add a trailing slash, path, query, fragment, or user
information.

Build a fixed pushed revision, then start that image:

```bash
QUANTUMSAVORY_REVISION=<full-commit-sha> docker compose build --pull
PUBLIC_URL=https://areweentangledyet.com docker compose up --detach --no-build
```

Use one host-level TLS reverse proxy in front of container port 8000. Proxy all
paths to that port and permit WebSocket upgrades. Do not configure separate
public routes to the Julia ports. The Compose file publishes one `8000:8000`
mapping; use the host firewall or reverse-proxy host policy to restrict direct
access when necessary.

For a slower host, override the backend startup deadline:

```bash
STARTUP_TIMEOUT_SECONDS=900 PUBLIC_URL=https://areweentangledyet.com \
    docker compose up --detach
```

Use a fixed image tag or digest for a production release. A built image is
self-contained, but this repository does not commit Julia manifests, so a later
rebuild can select newer compatible dependency releases.

## Application catalog

[`public/demos.json`](public/demos.json) is the sole application catalog used by
the landing page and launcher. Entries remain in display and startup order. Each
entry contains:

- `slug`, `title`, and `description` for identity and display
- `runtime` (`bonito` or `oxygen`)
- repository-relative `project` and `script` paths
- a unique internal `port`, positive `threads`, and unique `env_prefix`
- the public `entry_path` and direct-backend `health_path`
- HTTPS `docs_url` and `source_url` links

For Bonito, `entry_path` must be `/<slug>/` and `health_path` is `/`. For
Oxygen, both paths include the service prefix because Caddy preserves it. The
launcher validates all fields, uniqueness constraints, path containment, and
the generated Caddy configurations before it starts a child process. Internal
port 7999 is reserved for browser warmup and cannot be assigned to an
application.

After a catalog or source change, push the new commit, rebuild that revision,
and replace the running unit:

```bash
QUANTUMSAVORY_REVISION=<new-full-commit-sha> docker compose build --pull
docker compose up --detach --no-build
```

Changing the commit SHA invalidates the cached clone. If a moving branch such
as `master` must be fetched again under the same name, add `--no-cache` to the
build command.

To validate the catalog and generated Caddyfile in an already built image:

```bash
docker compose run --rm --no-deps areweentangledyet --validate-only
```

## Browser warmup

After all direct backend health checks pass, the launcher runs Chromium against
a temporary Caddy listener on `127.0.0.1:7999`. Chromium keeps `PUBLIC_URL` as
the page origin while it maps connections to that private listener. This also
exercises prefixed Bonito assets and WebSockets with production-like absolute
URLs. For an HTTPS origin, temporary Caddy uses a short-lived internal
certificate accepted only by the warmup browser.

[`warmup.mjs`](warmup.mjs) contains the applications with simple warmups. Each
application exposes a hidden Bonito button that starts its run. The driver waits
ten seconds after each page load and run, and only checks that the run produces
some server-to-browser WebSocket activity. Applications that require parameter
changes or more sophisticated interactions are not warmed.

The public port remains closed until the warmup exits. A warmup failure emits a
warning. A backend failure makes the container exit, so Compose restarts the
full unit.

## Public routing

Caddy redirects each Bonito root without a trailing slash, strips its public
prefix before proxying, and supplies each application with an absolute public
proxy URL. It preserves `/states_rest_server` for Oxygen so the API, Swagger UI,
and OpenAPI schema remain under the same prefix. Both REST service roots redirect
to `/states_rest_server/docs`.

The site does not send `X-Frame-Options` or a Content Security Policy that blocks
embedding. If an embedding page uses a sandboxed iframe, it must permit popups so
links can open without navigating the landing page. A functional sandbox is, for
example:

```html
<iframe
  src="https://areweentangledyet.com/"
  sandbox="allow-scripts allow-same-origin allow-popups"
  title="QuantumSavory live applications">
</iframe>
```

## Operations

Use `docker compose logs --follow` to inspect backend startup and each named
warmup action. The Compose health check reports healthy only after the landing
page is available. A backend exit makes the whole container exit nonzero and
restart.

After a production cutover, retire the old external deployment directory only
after the TLS proxy has been verified against this single port. TLS configuration
and DNS changes are host operations and are not part of this image.
