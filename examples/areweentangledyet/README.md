# Are We Entangled Yet?

This directory builds the complete [areweentangledyet.com](https://areweentangledyet.com/)
deployment as one container image. Caddy serves the landing page on port 8000 and
proxies HTTP and WebSocket traffic to seven Bonito applications and one Oxygen
API. The Julia services listen only on the container loopback interface.

The deployment is one failure domain. The launcher waits for every service
before it starts Caddy. If Caddy, Xvfb, or any Julia process exits, the launcher
stops and reaps the remaining processes and returns a nonzero status. Compose
then restarts the complete unit.

## Requirements

- Docker with the Compose plugin
- Outbound HTTPS access to GitHub and the Julia package servers during builds
- At least 16 GiB of available memory and 16 logical CPU cores for concurrent
  startup and interactive use
- Additional disk space and time for the first build because the image contains
  two precompiled Julia environments

Actual resource use depends on concurrent simulations. The color-center
application is normally the slowest service to become ready. The default
startup deadline is 600 seconds.

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

The build uses `julia:1.12.6-bookworm` and Caddy 2.10.2. It clones the complete
QuantumSavory.jl repository at `QUANTUMSAVORY_REVISION` (default `master`),
removes the Git history, and retains the tracked checkout in the image. It then
instantiates and precompiles both Julia environments. Container startup does not
clone a repository or run `Pkg.resolve`, `Pkg.update`, or any other
package-network operation.

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

For a slower host, override the startup deadline:

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
the generated Caddy configuration before it starts a child process.

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

Use `docker compose logs --follow` to inspect startup and service output. The
Compose health check reports healthy only after the landing page is available,
which means every backend passed its startup health check. A backend exit makes
the whole container exit nonzero and restart.

After a production cutover, retire the old external deployment directory only
after the TLS proxy has been verified against this single port. TLS configuration
and DNS changes are host operations and are not part of this image.
