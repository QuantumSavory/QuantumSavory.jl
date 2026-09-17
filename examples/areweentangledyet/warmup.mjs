import { spawn, spawnSync } from "node:child_process";
import { once } from "node:events";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { chromium } from "playwright-core";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const CATALOG = path.join(HERE, "public", "demos.json");
const CHROMIUM = "/usr/bin/chromium";
const PRIVATE_PORT = 7999;
const PUBLIC_URL = process.env.PUBLIC_URL ?? "http://localhost:8000";
const WAIT_MS = 10_000;

const WARMUPS = [
    ["first-generation repeater", "/firstgenrepeater/"],
    ["color-center trajectory", "/colorcentermodularcluster/single-trajectory"],
    ["repeater-chain congestion", "/congestionchain/"],
    ["simple entanglement switch", "/simpleswitch/"],
    ["asynchronous repeater grid", "/repeatergrid_async/"],
    ["synchronous repeater grid", "/repeatergrid_sync/"],
];

function caddyfile(origin, catalog) {
    const routes = catalog
        .filter((entry) => entry.runtime === "bonito")
        .map(
            (entry) =>
                `\thandle_path /${entry.slug}/* {\n\t\treverse_proxy 127.0.0.1:${entry.port}\n\t}`,
        )
        .join("\n");
    const tls = origin.protocol === "https:" ? "\n\ttls internal" : "";
    const autoHttps = origin.protocol === "https:" ? "disable_redirects" : "off";
    return `{\n\tauto_https ${autoHttps}\n\tadmin off\n}\n\n${origin.protocol}//${origin.hostname}:${PRIVATE_PORT} {\n\tbind 127.0.0.1${tls}\n${routes}\n}\n`;
}

async function runAndObserve(page, socket, application) {
    let activity = false;
    socket.once("framereceived", () => {
        activity = true;
    });
    await page.locator("button.warmup").dispatchEvent("click");
    await page.waitForTimeout(WAIT_MS);
    if (!activity) throw new Error(`${application}: no WebSocket activity after run`);
    console.log(`[warmup] ${application}: run`);
}

async function warmPage(browser, origin, [application, route]) {
    const context = await browser.newContext({
        ignoreHTTPSErrors: true,
        viewport: { width: 1600, height: 1200 },
    });
    try {
        const page = await context.newPage();
        const socketPromise = page.waitForEvent("websocket");
        const response = await page.goto(new URL(route, origin).href, {
            waitUntil: "domcontentloaded",
        });
        const socket = await socketPromise;
        if (!response?.ok()) throw new Error(`${application}: HTTP ${response?.status()}`);
        await page.waitForTimeout(WAIT_MS);

        await runAndObserve(page, socket, application);
    } finally {
        await context.close();
    }
}

async function run(origin, caddyPath, caddyEnvironment) {
    const caddy = spawn("caddy", ["run", "--config", caddyPath, "--adapter", "caddyfile"], {
        env: caddyEnvironment,
        stdio: "inherit",
    });
    let browser;
    try {
        await new Promise((resolve) => setTimeout(resolve, 500));
        browser = await chromium.launch({
            executablePath: CHROMIUM,
            headless: true,
            args: [
                "--no-sandbox",
                "--disable-dev-shm-usage",
                "--no-proxy-server",
                `--host-resolver-rules=MAP * 127.0.0.1:${PRIVATE_PORT}`,
            ],
        });
        for (const warmup of WARMUPS) {
            await warmPage(browser, origin, warmup);
        }
        console.log("[warmup] all configured runs produced WebSocket activity");
    } finally {
        await browser?.close().catch(() => {});
        if (caddy.exitCode === null) {
            const stopped = once(caddy, "exit");
            caddy.kill("SIGTERM");
            await Promise.race([stopped, new Promise((resolve) => setTimeout(resolve, 2_000))]);
        }
    }
}

async function main() {
    const origin = new URL(PUBLIC_URL);
    const catalog = JSON.parse(await readFile(CATALOG, "utf8"));
    const runtime = await mkdtemp(path.join(os.tmpdir(), "areweentangledyet-warmup-"));
    const caddyPath = path.join(runtime, "Caddyfile");
    const caddyEnvironment = {
        ...process.env,
        XDG_CONFIG_HOME: path.join(runtime, "caddy-config"),
        XDG_DATA_HOME: path.join(runtime, "caddy-data"),
    };
    try {
        await writeFile(caddyPath, caddyfile(origin, catalog));
        const validation = spawnSync("caddy", ["validate", "--config", caddyPath, "--adapter", "caddyfile"], {
            encoding: "utf8",
            env: caddyEnvironment,
        });
        if (validation.status !== 0) throw new Error(validation.stderr || validation.stdout);

        if (process.argv[2] === "--validate-only") {
            const version = spawnSync(CHROMIUM, ["--version"], { encoding: "utf8" });
            if (version.status !== 0) throw new Error(version.stderr);
            console.log(`Browser warmup and ${version.stdout.trim()} are valid.`);
            return;
        }

        await run(origin, caddyPath, caddyEnvironment);
    } finally {
        await rm(runtime, { recursive: true, force: true });
    }
}

main().catch((error) => {
    console.error(`areweentangledyet warmup: ${error.message}`);
    process.exitCode = 1;
});
