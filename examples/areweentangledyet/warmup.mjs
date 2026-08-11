import { createHash } from "node:crypto";
import { once } from "node:events";
import { constants as fsConstants } from "node:fs";
import { access, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import net from "node:net";
import os from "node:os";
import path from "node:path";
import { spawn, spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright-core";

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const CATALOG_PATH = path.join(SCRIPT_DIR, "public", "demos.json");
const CHROMIUM_PATH = "/usr/bin/chromium";
const WARMUP_PORT = 7999;
const PUBLIC_URL = process.env.PUBLIC_URL ?? "http://localhost:8000";
const WARMUP_TIMEOUT_SECONDS = positiveInteger(
    process.env.WARMUP_TIMEOUT_SECONDS ?? "600",
    "WARMUP_TIMEOUT_SECONDS",
);

// Coordinates are fractions of the current canvas width and height. Exact canvas
// dimensions intentionally make layout changes fail instead of clicking elsewhere.
const WARMUPS = [
    {
        name: "first-generation repeater",
        slug: "firstgenrepeater",
        path: "/firstgenrepeater/",
        canvas: [1100, 900],
        timeoutMs: 120_000,
        actions: [
            { name: "shorten simulation horizon", type: "change", point: [0.14, 0.655] },
            { name: "run simulation", type: "finite", point: [0.50, 0.50] },
        ],
    },
    {
        name: "color-center ensemble",
        slug: "colorcentermodularcluster",
        path: "/colorcentermodularcluster/ensemble",
        canvas: [1200, 600],
        timeoutMs: 120_000,
        actions: [{ name: "run and stop ensemble", type: "toggle", point: [0.527, 0.960] }],
    },
    {
        name: "color-center trajectory",
        slug: "colorcentermodularcluster",
        path: "/colorcentermodularcluster/single-trajectory",
        canvas: [1200, 800],
        timeoutMs: 180_000,
        actions: [{ name: "run trajectory", type: "finite", point: [0.534, 0.970] }],
    },
    {
        name: "repeater-chain congestion",
        slug: "congestionchain",
        path: "/congestionchain/",
        canvas: [800, 700],
        timeoutMs: 120_000,
        actions: [{ name: "run simulation", type: "finite", point: [0.114, 0.501] }],
    },
    {
        name: "simple entanglement switch",
        slug: "simpleswitch",
        path: "/simpleswitch/",
        canvas: [1600, 800],
        timeoutMs: 180_000,
        actions: [
            { name: "change global request rate", type: "change", point: [0.500, 0.909] },
            { name: "run simulation", type: "finite", point: [0.500, 0.961] },
        ],
    },
    {
        name: "asynchronous repeater grid",
        slug: "repeatergrid_async",
        path: "/repeatergrid_async/",
        canvas: [1200, 1100],
        timeoutMs: 120_000,
        actions: [
            { name: "change success probability", type: "change", point: [0.690, 0.760] },
            { name: "run simulation", type: "finite", point: [0.518, 0.973] },
        ],
    },
    {
        name: "synchronous repeater grid",
        slug: "repeatergrid_sync",
        path: "/repeatergrid_sync/",
        canvas: [1200, 1100],
        timeoutMs: 120_000,
        actions: [
            { name: "change success probability", type: "change", point: [0.690, 0.760] },
            { name: "run simulation", type: "finite", point: [0.518, 0.973] },
        ],
    },
    {
        name: "Barrett-Kok state",
        slug: "state_explorer",
        path: "/state_explorer/vis/BarrettKokBellPairW",
        canvas: [600, 490],
        timeoutMs: 120_000,
        actions: [{ name: "change state parameter", type: "change", point: [0.17, 0.958] }],
    },
    {
        name: "Genqo unheralded state",
        slug: "state_explorer",
        path: "/state_explorer/vis/GenqoUnheraldedSPDCBellPairW",
        canvas: [600, 490],
        timeoutMs: 120_000,
        actions: [{ name: "change state parameter", type: "change", point: [0.22, 0.958] }],
    },
    {
        name: "Genqo cascaded state",
        slug: "state_explorer",
        path: "/state_explorer/vis/GenqoMultiplexedCascadedBellPairW",
        canvas: [600, 490],
        timeoutMs: 180_000,
        actions: [{ name: "change state parameter", type: "change", point: [0.18, 0.958] }],
    },
    {
        name: "depolarized state",
        slug: "state_explorer",
        path: "/state_explorer/vis/DepolarizedBellPair",
        canvas: [600, 490],
        timeoutMs: 120_000,
        actions: [{ name: "change state parameter", type: "change", point: [0.50, 0.958] }],
    },
];

let browser;
let caddy;
let stoppingBrowser = false;
let stoppingCaddy = false;
let abortError;
let rejectAbort;
const abortPromise = new Promise((_, reject) => {
    rejectAbort = reject;
});
abortPromise.catch(() => {});

function positiveInteger(value, name) {
    if (!/^[1-9][0-9]*$/.test(value)) {
        throw new Error(`${name} must be a positive integer`);
    }
    return Number(value);
}

function publicOrigin() {
    let origin;
    try {
        origin = new URL(PUBLIC_URL);
    } catch {
        throw new Error("PUBLIC_URL must be an absolute HTTP(S) origin");
    }
    if (
        !["http:", "https:"].includes(origin.protocol) ||
        origin.username ||
        origin.password ||
        origin.pathname !== "/" ||
        origin.search ||
        origin.hash ||
        PUBLIC_URL.endsWith("/")
    ) {
        throw new Error("PUBLIC_URL must contain only an HTTP(S) scheme, host, and optional port");
    }
    return origin;
}

function validateWarmups(catalog) {
    if (!Array.isArray(catalog)) throw new Error("catalog must be an array");
    const bonito = catalog.filter((entry) => entry.runtime === "bonito");
    const entries = new Map(bonito.map((entry) => [entry.slug, entry]));
    const covered = new Set();
    const actionTypes = new Set(["change", "finite", "toggle"]);

    for (const entry of catalog) {
        if (entry.port === WARMUP_PORT) {
            throw new Error(`catalog port ${WARMUP_PORT} is reserved for browser warmup`);
        }
    }
    for (const warmup of WARMUPS) {
        const entry = entries.get(warmup.slug);
        if (!entry) throw new Error(`warmup references unknown Bonito slug: ${warmup.slug}`);
        if (!warmup.path.startsWith(entry.entry_path)) {
            throw new Error(`warmup path escapes ${entry.entry_path}: ${warmup.path}`);
        }
        if (
            !Array.isArray(warmup.canvas) ||
            warmup.canvas.length !== 2 ||
            warmup.canvas.some((value) => !Number.isInteger(value) || value <= 0)
        ) {
            throw new Error(`invalid canvas dimensions for ${warmup.name}`);
        }
        if (!Number.isInteger(warmup.timeoutMs) || warmup.timeoutMs <= 0) {
            throw new Error(`invalid timeout for ${warmup.name}`);
        }
        if (!Array.isArray(warmup.actions) || warmup.actions.length === 0) {
            throw new Error(`no actions configured for ${warmup.name}`);
        }
        for (const action of warmup.actions) {
            if (!actionTypes.has(action.type)) {
                throw new Error(`invalid action type for ${warmup.name}: ${action.type}`);
            }
            if (
                !Array.isArray(action.point) ||
                action.point.length !== 2 ||
                action.point.some((value) => typeof value !== "number" || value <= 0 || value >= 1)
            ) {
                throw new Error(`invalid relative click for ${warmup.name}: ${action.name}`);
            }
        }
        covered.add(warmup.slug);
    }

    const missing = [...entries.keys()].filter((slug) => !covered.has(slug));
    if (missing.length) throw new Error(`Bonito warmup directives missing for: ${missing.join(", ")}`);
}

function caddyfile(origin, catalog) {
    const lines = [
        "{",
        `\tauto_https ${origin.protocol === "https:" ? "disable_redirects" : "off"}`,
        "\tadmin off",
        "}",
        "",
        `${origin.protocol}//${origin.hostname}:${WARMUP_PORT} {`,
        "\tbind 127.0.0.1",
    ];
    if (origin.protocol === "https:") lines.push("\ttls internal");
    for (const entry of catalog.filter((item) => item.runtime === "bonito")) {
        lines.push(
            `\thandle_path /${entry.slug}/* {`,
            `\t\treverse_proxy 127.0.0.1:${entry.port}`,
            "\t}",
        );
    }
    lines.push("\trespond 404", "}", "");
    return lines.join("\n");
}

function caddyEnvironment(runtimeDir) {
    return {
        ...process.env,
        XDG_CONFIG_HOME: path.join(runtimeDir, "caddy-config"),
        XDG_DATA_HOME: path.join(runtimeDir, "caddy-data"),
    };
}

function validateCaddy(caddyfilePath, runtimeDir) {
    const result = spawnSync(
        "caddy",
        ["validate", "--config", caddyfilePath, "--adapter", "caddyfile"],
        { encoding: "utf8", env: caddyEnvironment(runtimeDir) },
    );
    if (result.status !== 0) {
        throw new Error(`private Caddy configuration is invalid:\n${result.stderr || result.stdout}`);
    }
}

function requestAbort(error) {
    if (abortError) return;
    abortError = error;
    rejectAbort(error);
    if (browser) void browser.close().catch(() => {});
    if (caddy && caddy.exitCode === null) caddy.kill("SIGTERM");
}

async function bounded(promise, deadline, description) {
    const remaining = Math.min(deadline - Date.now(), globalDeadline - Date.now());
    if (remaining <= 0) throw new Error(`timed out while ${description}`);
    let timer;
    const timeout = new Promise((_, reject) => {
        timer = setTimeout(() => reject(new Error(`timed out while ${description}`)), remaining);
    });
    try {
        return await Promise.race([promise, timeout, abortPromise]);
    } finally {
        clearTimeout(timer);
    }
}

async function pause(milliseconds, deadline, description = "waiting for rendering") {
    await bounded(new Promise((resolve) => setTimeout(resolve, milliseconds)), deadline, description);
}

async function waitForPort(deadline) {
    while (true) {
        const connected = await new Promise((resolve) => {
            const socket = net.createConnection({ host: "127.0.0.1", port: WARMUP_PORT });
            socket.once("connect", () => {
                socket.destroy();
                resolve(true);
            });
            socket.once("error", () => resolve(false));
        });
        if (connected) return;
        await pause(100, deadline, "waiting for private Caddy");
    }
}

async function startCaddy(caddyfilePath, runtimeDir, deadline) {
    caddy = spawn(
        "caddy",
        ["run", "--config", caddyfilePath, "--adapter", "caddyfile"],
        { env: caddyEnvironment(runtimeDir), stdio: ["ignore", "inherit", "inherit"] },
    );
    caddy.once("error", (error) => requestAbort(new Error(`private Caddy failed: ${error.message}`)));
    caddy.once("exit", (code, signal) => {
        if (!stoppingCaddy) {
            requestAbort(new Error(`private Caddy exited early (${signal ?? `status ${code}`})`));
        }
    });
    await waitForPort(deadline);
}

async function stopCaddy() {
    if (!caddy || caddy.exitCode !== null) return;
    stoppingCaddy = true;
    const exited = once(caddy, "exit");
    caddy.kill("SIGTERM");
    const graceful = await Promise.race([
        exited.then(() => true),
        new Promise((resolve) => setTimeout(() => resolve(false), 5_000)),
    ]);
    if (!graceful && caddy.exitCode === null) {
        caddy.kill("SIGKILL");
        await once(caddy, "exit");
    }
}

function hash(image) {
    return createHash("sha256").update(image).digest("hex");
}

async function canvas(page, warmup, deadline) {
    const [expectedWidth, expectedHeight] = warmup.canvas;
    let observed = [];
    while (true) {
        const canvases = page.locator("canvas");
        observed = await bounded(
            canvases.evaluateAll((elements) =>
                elements.map((element, index) => {
                    const box = element.getBoundingClientRect();
                    return { index, width: box.width, height: box.height, visible: box.width > 0 && box.height > 0 };
                }),
            ),
            deadline,
            `finding the ${warmup.name} canvas`,
        );
        const match = observed.find(
            (item) => item.visible && Math.round(item.width) === expectedWidth && Math.round(item.height) === expectedHeight,
        );
        if (match) {
            const locator = canvases.nth(match.index);
            const box = await bounded(locator.boundingBox(), deadline, `measuring the ${warmup.name} canvas`);
            if (box) return { locator, box };
        }
        if (Date.now() >= deadline || Date.now() >= globalDeadline) {
            const dimensions = observed.filter((item) => item.visible).map((item) => `${item.width}x${item.height}`);
            throw new Error(
                `${warmup.name} expected a ${expectedWidth}x${expectedHeight} canvas; found ${dimensions.join(", ") || "none"}`,
            );
        }
        await pause(200, deadline);
    }
}

async function snapshot(page, warmup, deadline, point) {
    for (let attempt = 0; attempt < 2; attempt += 1) {
        try {
            const current = await canvas(page, warmup, deadline);
            if (!point) {
                return hash(await bounded(
                    current.locator.screenshot({ animations: "disabled" }),
                    deadline,
                    `capturing the ${warmup.name} canvas`,
                ));
            }
            const scroll = await page.evaluate(() => ({ x: window.scrollX, y: window.scrollY }));
            const centerX = current.box.x + scroll.x + current.box.width * point[0];
            const centerY = current.box.y + scroll.y + current.box.height * point[1];
            const halfWidth = Math.min(90, current.box.width * 0.08);
            const halfHeight = Math.min(25, current.box.height * 0.025);
            const left = Math.max(current.box.x + scroll.x, centerX - halfWidth);
            const top = Math.max(current.box.y + scroll.y, centerY - halfHeight);
            const right = Math.min(current.box.x + scroll.x + current.box.width, centerX + halfWidth);
            const bottom = Math.min(current.box.y + scroll.y + current.box.height, centerY + halfHeight);
            return hash(await bounded(
                page.screenshot({ clip: { x: left, y: top, width: right - left, height: bottom - top } }),
                deadline,
                `capturing the ${warmup.name} control`,
            ));
        } catch (error) {
            if (attempt === 1) throw error;
        }
    }
}

async function click(page, warmup, point, deadline) {
    const current = await canvas(page, warmup, deadline);
    await page.mouse.click(
        current.box.x + current.box.width * point[0],
        current.box.y + current.box.height * point[1],
    );
    await page.mouse.move(0, 0);
}

async function waitForQuietCanvas(page, warmup, deadline) {
    let previous;
    let repetitions = 0;
    while (repetitions < 3) {
        const current = await snapshot(page, warmup, deadline);
        repetitions = current === previous ? repetitions + 1 : 0;
        previous = current;
        await pause(250, deadline);
    }
    return previous;
}

async function waitForChangedSnapshot(page, warmup, deadline, initial, point, description) {
    while (true) {
        const current = await snapshot(page, warmup, deadline, point);
        if (current !== initial) return current;
        await pause(50, deadline, description);
    }
}

async function changeControl(page, warmup, action, deadline) {
    await page.mouse.move(0, 0);
    const initial = await waitForQuietCanvas(page, warmup, deadline);
    await click(page, warmup, action.point, deadline);
    await waitForChangedSnapshot(page, warmup, deadline, initial, undefined, action.name);
    const final = await waitForQuietCanvas(page, warmup, deadline);
    if (final === initial) throw new Error(`${action.name} returned to its initial rendering`);
}

async function runFinite(page, warmup, action, deadline) {
    await page.mouse.move(0, 0);
    await waitForQuietCanvas(page, warmup, deadline);
    const initialButton = await snapshot(page, warmup, deadline, action.point);
    const images = new Set([await snapshot(page, warmup, deadline)]);
    await click(page, warmup, action.point, deadline);
    const runningButton = await waitForChangedSnapshot(
        page,
        warmup,
        deadline,
        initialButton,
        action.point,
        `${action.name} to start`,
    );
    images.add(await snapshot(page, warmup, deadline));
    await waitForChangedSnapshot(
        page,
        warmup,
        deadline,
        runningButton,
        action.point,
        `${action.name} to finish`,
    );
    images.add(await snapshot(page, warmup, deadline));
    await waitForQuietCanvas(page, warmup, deadline);
    if (images.size < 3) throw new Error(`${action.name} did not produce two observable canvas transitions`);
}

async function runAndStop(page, warmup, action, deadline) {
    await page.mouse.move(0, 0);
    const initialCanvas = await waitForQuietCanvas(page, warmup, deadline);
    const initialButton = await snapshot(page, warmup, deadline, action.point);
    await click(page, warmup, action.point, deadline);
    const runningButton = await waitForChangedSnapshot(
        page,
        warmup,
        deadline,
        initialButton,
        action.point,
        `${action.name} to start`,
    );
    const images = new Set([initialCanvas]);
    while (images.size < 3) {
        images.add(await snapshot(page, warmup, deadline));
        await pause(250, deadline, `${action.name} to render`);
    }
    await click(page, warmup, action.point, deadline);
    await waitForChangedSnapshot(
        page,
        warmup,
        deadline,
        runningButton,
        action.point,
        `${action.name} to stop`,
    );
    await waitForQuietCanvas(page, warmup, deadline);
}

function monitorPage(page, origin) {
    const failures = [];
    let websocketCount = 0;
    let resolveWebsocket;
    const websocketReady = new Promise((resolve) => {
        resolveWebsocket = resolve;
    });
    const isLocal = (url) => {
        try {
            return new URL(url).host === origin.host;
        } catch {
            return false;
        }
    };

    page.on("pageerror", (error) => failures.push(`page error: ${error.message}`));
    page.on("requestfailed", (request) => {
        if (isLocal(request.url())) failures.push(`request failed: ${request.url()} (${request.failure()?.errorText})`);
    });
    page.on("response", (response) => {
        if (isLocal(response.url()) && response.status() >= 400) {
            failures.push(`HTTP ${response.status()}: ${response.url()}`);
        }
    });
    page.on("websocket", (socket) => {
        if (!isLocal(socket.url())) return;
        websocketCount += 1;
        resolveWebsocket();
        socket.on("socketerror", (error) => failures.push(`WebSocket error: ${error}`));
    });

    return {
        assertHealthy() {
            if (failures.length) throw new Error(failures.join("; "));
        },
        async waitForWebsocket(deadline, name) {
            if (websocketCount === 0) {
                await bounded(websocketReady, deadline, `waiting for the ${name} WebSocket`);
            }
        },
    };
}

async function warmAttempt(origin, warmup) {
    const deadline = Math.min(Date.now() + warmup.timeoutMs, globalDeadline);
    const context = await bounded(
        browser.newContext({
            deviceScaleFactor: 1,
            ignoreHTTPSErrors: true,
            viewport: { width: 1600, height: 1200 },
        }),
        deadline,
        `creating a browser context for ${warmup.name}`,
    );
    try {
        const page = await context.newPage();
        const monitor = monitorPage(page, origin);
        const response = await bounded(
            page.goto(new URL(warmup.path, origin).href, { waitUntil: "domcontentloaded" }),
            deadline,
            `loading ${warmup.name}`,
        );
        if (!response || !response.ok()) {
            throw new Error(`${warmup.name} navigation returned HTTP ${response?.status() ?? "failure"}`);
        }
        await monitor.waitForWebsocket(deadline, warmup.name);
        const current = await canvas(page, warmup, deadline);
        console.log(
            `[warmup] ${warmup.name}: canvas ${current.box.width.toFixed(0)}x${current.box.height.toFixed(0)}`,
        );
        await waitForQuietCanvas(page, warmup, deadline);
        monitor.assertHealthy();

        for (const action of warmup.actions) {
            console.log(`[warmup] ${warmup.name}: ${action.name}`);
            if (action.type === "change") await changeControl(page, warmup, action, deadline);
            if (action.type === "finite") await runFinite(page, warmup, action, deadline);
            if (action.type === "toggle") await runAndStop(page, warmup, action, deadline);
            monitor.assertHealthy();
        }
    } finally {
        await context.close().catch(() => {});
    }
}

async function warmAll(origin) {
    for (const warmup of WARMUPS) {
        const started = Date.now();
        let lastError;
        for (let attempt = 1; attempt <= 2; attempt += 1) {
            try {
                await warmAttempt(origin, warmup);
                console.log(`[warmup] ${warmup.name}: ready in ${((Date.now() - started) / 1000).toFixed(1)}s`);
                lastError = undefined;
                break;
            } catch (error) {
                lastError = error;
                if (abortError) throw abortError;
                if (attempt === 1) console.warn(`[warmup] ${warmup.name}: retrying after ${error.message}`);
            }
        }
        if (lastError) throw new Error(`${warmup.name} failed after one retry: ${lastError.message}`);
    }
}

async function validateOnly(origin, catalog) {
    const runtimeDir = await mkdtemp(path.join(os.tmpdir(), "areweentangledyet-warmup-"));
    try {
        const caddyfilePath = path.join(runtimeDir, "Caddyfile");
        await writeFile(caddyfilePath, caddyfile(origin, catalog));
        validateCaddy(caddyfilePath, runtimeDir);
        await access(CHROMIUM_PATH, fsConstants.X_OK);
        const version = spawnSync(CHROMIUM_PATH, ["--version"], { encoding: "utf8" });
        if (version.status !== 0) throw new Error(`Chromium cannot start: ${version.stderr}`);
        console.log(`Browser warmup directives, private Caddy, and ${version.stdout.trim()} are valid.`);
    } finally {
        await rm(runtimeDir, { recursive: true, force: true });
    }
}

let globalDeadline = Number.POSITIVE_INFINITY;

async function run(origin, catalog) {
    const runtimeDir = await mkdtemp(path.join(os.tmpdir(), "areweentangledyet-warmup-"));
    globalDeadline = Date.now() + WARMUP_TIMEOUT_SECONDS * 1000;
    const globalTimer = setTimeout(
        () => requestAbort(new Error(`browser warmup exceeded ${WARMUP_TIMEOUT_SECONDS} seconds`)),
        WARMUP_TIMEOUT_SECONDS * 1000,
    );
    const onSigint = () => requestAbort(new Error("browser warmup received SIGINT"));
    const onSigterm = () => requestAbort(new Error("browser warmup received SIGTERM"));
    process.once("SIGINT", onSigint);
    process.once("SIGTERM", onSigterm);
    try {
        const caddyfilePath = path.join(runtimeDir, "Caddyfile");
        await writeFile(caddyfilePath, caddyfile(origin, catalog));
        validateCaddy(caddyfilePath, runtimeDir);
        await startCaddy(caddyfilePath, runtimeDir, globalDeadline);
        browser = await bounded(
            chromium.launch({
                executablePath: CHROMIUM_PATH,
                headless: true,
                args: [
                    "--no-sandbox",
                    "--disable-dev-shm-usage",
                    "--disable-background-networking",
                    "--disable-component-update",
                    "--disable-default-apps",
                    "--disable-sync",
                    "--metrics-recording-only",
                    "--no-first-run",
                    "--no-proxy-server",
                    `--host-resolver-rules=MAP * 127.0.0.1:${WARMUP_PORT}`,
                ],
            }),
            globalDeadline,
            "starting Chromium",
        );
        browser.once("disconnected", () => {
            if (!stoppingBrowser && !abortError) requestAbort(new Error("Chromium disconnected during warmup"));
        });
        await Promise.race([warmAll(origin), abortPromise]);
        console.log("[warmup] all Bonito applications are ready");
    } finally {
        clearTimeout(globalTimer);
        process.removeListener("SIGINT", onSigint);
        process.removeListener("SIGTERM", onSigterm);
        stoppingBrowser = true;
        if (browser) await browser.close().catch(() => {});
        await stopCaddy();
        await rm(runtimeDir, { recursive: true, force: true });
    }
}

async function main() {
    const mode = process.argv[2] ?? "run";
    if (!["run", "--validate-only"].includes(mode) || process.argv.length > 3) {
        throw new Error(`usage: node ${path.basename(process.argv[1])} [--validate-only]`);
    }
    const origin = publicOrigin();
    const catalog = JSON.parse(await readFile(CATALOG_PATH, "utf8"));
    validateWarmups(catalog);
    if (mode === "--validate-only") await validateOnly(origin, catalog);
    else await run(origin, catalog);
}

main().catch((error) => {
    console.error(`areweentangledyet warmup: ${error.message}`);
    process.exitCode = 1;
});
