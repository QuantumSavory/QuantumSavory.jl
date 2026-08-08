#!/usr/bin/env bash
set -Eeuo pipefail

readonly SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
readonly PUBLIC_DIR="$SCRIPT_DIR/public"
readonly CATALOG="$PUBLIC_DIR/demos.json"
readonly PUBLIC_PORT=8000

PUBLIC_URL="${PUBLIC_URL:-http://localhost:8000}"
STARTUP_TIMEOUT_SECONDS="${STARTUP_TIMEOUT_SECONDS:-600}"

declare -a CHILD_PIDS=()
declare -A CHILD_NAMES=()
RUNTIME_DIR=""

die() {
    printf 'areweentangledyet: %s\n' "$*" >&2
    exit 1
}

child_is_running() {
    local wanted="$1"
    local running
    while IFS= read -r running; do
        [[ "$running" == "$wanted" ]] && return 0
    done < <(jobs -pr)
    return 1
}

terminate_children() {
    local pid
    local deadline

    ((${#CHILD_PIDS[@]} == 0)) && return
    kill -TERM "${CHILD_PIDS[@]}" 2>/dev/null || true
    deadline=$((SECONDS + 15))

    while ((SECONDS < deadline)); do
        local any_running=false
        for pid in "${CHILD_PIDS[@]}"; do
            if child_is_running "$pid"; then
                any_running=true
                break
            fi
        done
        [[ "$any_running" == false ]] && break
        sleep 0.2
    done

    for pid in "${CHILD_PIDS[@]}"; do
        child_is_running "$pid" && kill -KILL "$pid" 2>/dev/null || true
    done
    for pid in "${CHILD_PIDS[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
}

on_exit() {
    local status=$?
    trap - EXIT INT TERM
    terminate_children
    if [[ -n "$RUNTIME_DIR" && -d "$RUNTIME_DIR" ]]; then
        rm -rf -- "$RUNTIME_DIR"
    fi
    exit "$status"
}

trap on_exit EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

validate_public_url() {
    local port=""

    if [[ ! "$PUBLIC_URL" =~ ^https?://(\[[0-9A-Fa-f:.]+\]|[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?)(:([0-9]{1,5}))?$ ]]; then
        die "PUBLIC_URL must be an absolute HTTP(S) origin without a trailing slash, path, query, fragment, or user information"
    fi
    port="${BASH_REMATCH[4]:-}"
    if [[ -n "$port" ]] && ((10#$port < 1 || 10#$port > 65535)); then
        die "PUBLIC_URL contains an invalid port"
    fi
}

validate_catalog() {
    [[ -f "$CATALOG" ]] || die "catalog not found: $CATALOG"

    jq -e '
        def nonempty_string: type == "string" and length > 0;
        def safe_relative_path:
            nonempty_string and
            test("^[A-Za-z0-9._/-]+$") and
            (startswith("/") | not) and
            (split("/") | all(. != "" and . != "." and . != ".."));
        def required_keys: [
            "description", "docs_url", "entry_path", "env_prefix", "health_path",
            "port", "project", "runtime", "script", "slug", "source_url", "threads", "title"
        ];
        type == "array" and length > 0 and
        all(.[];
            type == "object" and keys == required_keys and
            (.slug | nonempty_string and test("^[a-z0-9]+([_-][a-z0-9]+)*$")) and
            (.title | nonempty_string) and
            (.description | nonempty_string) and
            (.runtime == "bonito" or .runtime == "oxygen") and
            (.project | safe_relative_path) and
            (.script | safe_relative_path and endswith(".jl")) and
            (.port | type == "number" and . == floor and . >= 1 and . <= 65535 and . != 8000) and
            (.threads | type == "number" and . == floor and . >= 1 and . <= 64) and
            (.env_prefix | nonempty_string and test("^QS_[A-Z0-9]+(_[A-Z0-9]+)*$")) and
            (.entry_path | nonempty_string and test("^/[a-z0-9_/-]+$") and (contains("//") | not)) and
            (.health_path | nonempty_string and test("^/[a-z0-9_/-]*$") and (contains("//") | not)) and
            (.docs_url | nonempty_string and test("^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(/[^[:space:]]*)?$")) and
            (.source_url | nonempty_string and test("^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(/[^[:space:]]*)?$")) and
            if .runtime == "bonito" then
                .entry_path == ("/" + .slug + "/") and .health_path == "/"
            else
                . as $entry |
                (.entry_path | startswith("/" + $entry.slug + "/")) and
                (.health_path | startswith("/" + $entry.slug + "/"))
            end
        ) and
        ([.[].slug] | length == (unique | length)) and
        ([.[].port] | length == (unique | length)) and
        ([.[].env_prefix] | length == (unique | length)) and
        ([.[].entry_path] | length == (unique | length))
    ' "$CATALOG" >/dev/null || die "catalog validation failed"

    local item project script project_path script_path
    while IFS= read -r item; do
        project="$(jq -r '.project' <<<"$item")"
        script="$(jq -r '.script' <<<"$item")"
        project_path="$(realpath -e -- "$REPO_ROOT/$project")" || die "project does not exist: $project"
        script_path="$(realpath -e -- "$REPO_ROOT/$script")" || die "script does not exist: $script"
        [[ "$project_path" == "$REPO_ROOT/"* && -d "$project_path" ]] || die "project escapes the repository: $project"
        [[ -f "$project_path/Project.toml" ]] || die "project has no Project.toml: $project"
        [[ "$script_path" == "$REPO_ROOT/"* && -f "$script_path" ]] || die "script escapes the repository: $script"
    done < <(jq -c '.[]' "$CATALOG")
}

generate_caddyfile() {
    local caddyfile="$1"
    local item slug runtime port entry_path

    {
        printf '{\n\tauto_https off\n\tadmin off\n}\n\n'
        printf ':%s {\n' "$PUBLIC_PORT"
        while IFS= read -r item; do
            slug="$(jq -r '.slug' <<<"$item")"
            runtime="$(jq -r '.runtime' <<<"$item")"
            port="$(jq -r '.port' <<<"$item")"
            entry_path="$(jq -r '.entry_path' <<<"$item")"

            if [[ "$runtime" == "bonito" ]]; then
                printf '\tredir /%s /%s/ 308\n' "$slug" "$slug"
                printf '\thandle_path /%s/* {\n' "$slug"
                printf '\t\treverse_proxy 127.0.0.1:%s\n' "$port"
                printf '\t}\n'
            else
                printf '\tredir /%s %s 308\n' "$slug" "$entry_path"
                printf '\tredir /%s/ %s 308\n' "$slug" "$entry_path"
                printf '\thandle /%s/* {\n' "$slug"
                printf '\t\treverse_proxy 127.0.0.1:%s\n' "$port"
                printf '\t}\n'
            fi
        done < <(jq -c '.[]' "$CATALOG")
        printf '\thandle {\n'
        printf '\t\troot * "%s"\n' "$PUBLIC_DIR"
        printf '\t\tfile_server\n'
        printf '\t}\n'
        printf '}\n'
    } >"$caddyfile"
}

start_child() {
    local name="$1"
    shift
    "$@" &
    local pid=$!
    CHILD_PIDS+=("$pid")
    CHILD_NAMES["$pid"]="$name"
    printf 'Started %s (PID %s)\n' "$name" "$pid"
}

check_startup_children() {
    local pid
    local status
    for pid in "${CHILD_PIDS[@]}"; do
        if ! child_is_running "$pid"; then
            set +e
            wait "$pid"
            status=$?
            set -e
            die "${CHILD_NAMES[$pid]} exited during startup with status $status"
        fi
    done
}

start_xvfb() {
    export DISPLAY=:99
    start_child "Xvfb" Xvfb "$DISPLAY" -screen 0 1280x1024x24 -nolisten tcp -noreset

    local deadline=$((SECONDS + 10))
    while [[ ! -S /tmp/.X11-unix/X99 ]]; do
        check_startup_children
        ((SECONDS < deadline)) || die "Xvfb did not become ready"
        sleep 0.1
    done
}

start_services() {
    local item slug runtime project script port threads env_prefix entry_path docs_path proxy_url

    while IFS= read -r item; do
        slug="$(jq -r '.slug' <<<"$item")"
        runtime="$(jq -r '.runtime' <<<"$item")"
        project="$(jq -r '.project' <<<"$item")"
        script="$(jq -r '.script' <<<"$item")"
        port="$(jq -r '.port' <<<"$item")"
        threads="$(jq -r '.threads' <<<"$item")"
        env_prefix="$(jq -r '.env_prefix' <<<"$item")"
        entry_path="$(jq -r '.entry_path' <<<"$item")"

        if [[ "$runtime" == "bonito" ]]; then
            proxy_url="$PUBLIC_URL$entry_path"
            start_child "$slug" env \
                "${env_prefix}_IP=127.0.0.1" \
                "${env_prefix}_PORT=$port" \
                "${env_prefix}_PROXY=$proxy_url" \
                julia --startup-file=no --history-file=no --project="$REPO_ROOT/$project" --threads="$threads" "$REPO_ROOT/$script"
        else
            docs_path="${entry_path#/$slug}"
            start_child "$slug" env \
                "${env_prefix}_IP=127.0.0.1" \
                "${env_prefix}_PORT=$port" \
                "${env_prefix}_PROXY=$PUBLIC_URL" \
                "${env_prefix}_PREFIX=/$slug" \
                "${env_prefix}_DOCPATH=$docs_path" \
                julia --startup-file=no --history-file=no --project="$REPO_ROOT/$project" --threads="$threads" "$REPO_ROOT/$script"
        fi
    done < <(jq -c '.[]' "$CATALOG")
}

wait_for_services() {
    local deadline=$((SECONDS + STARTUP_TIMEOUT_SECONDS))
    local total ready_count=0
    local item slug port health_path health_url
    declare -A ready=()

    total="$(jq 'length' "$CATALOG")"
    while ((ready_count < total)); do
        check_startup_children
        while IFS= read -r item; do
            slug="$(jq -r '.slug' <<<"$item")"
            [[ "${ready[$slug]:-}" == true ]] && continue
            port="$(jq -r '.port' <<<"$item")"
            health_path="$(jq -r '.health_path' <<<"$item")"
            health_url="http://127.0.0.1:$port$health_path"

            if curl --fail --silent --show-error --max-time 5 --output /dev/null "$health_url" 2>/dev/null; then
                ready["$slug"]=true
                ready_count=$((ready_count + 1))
                printf 'Healthy: %s (%s/%s)\n' "$slug" "$ready_count" "$total"
            fi
        done < <(jq -c '.[]' "$CATALOG")

        ((ready_count == total)) && break
        ((SECONDS < deadline)) || die "services did not become healthy within ${STARTUP_TIMEOUT_SECONDS} seconds"
        sleep 1
    done
}

supervise() {
    local exited_pid=""
    local status

    set +e
    wait -n -p exited_pid "${CHILD_PIDS[@]}"
    status=$?
    set -e
    [[ -n "$exited_pid" ]] || die "process supervision failed"
    ((status == 0)) && status=1
    printf 'areweentangledyet: %s exited with status %s; stopping the deployment\n' "${CHILD_NAMES[$exited_pid]}" "$status" >&2
    exit "$status"
}

main() {
    local mode="${1:-run}"
    [[ "$mode" == "run" || "$mode" == "--validate-only" ]] || die "usage: $0 [--validate-only]"
    [[ "$STARTUP_TIMEOUT_SECONDS" =~ ^[1-9][0-9]*$ ]] || die "STARTUP_TIMEOUT_SECONDS must be a positive integer"

    validate_public_url
    validate_catalog
    RUNTIME_DIR="$(mktemp -d)"
    generate_caddyfile "$RUNTIME_DIR/Caddyfile"
    caddy validate --config "$RUNTIME_DIR/Caddyfile" --adapter caddyfile

    if [[ "$mode" == "--validate-only" ]]; then
        printf 'Catalog, PUBLIC_URL, and generated Caddy configuration are valid.\n'
        return
    fi

    start_xvfb
    start_services
    wait_for_services
    start_child "Caddy" caddy run --config "$RUNTIME_DIR/Caddyfile" --adapter caddyfile
    supervise
}

main "$@"
