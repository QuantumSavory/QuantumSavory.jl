"use strict";

const catalogFields = [
  "slug",
  "title",
  "description",
  "runtime",
  "project",
  "script",
  "port",
  "threads",
  "env_prefix",
  "entry_path",
  "health_path",
  "docs_url",
  "source_url",
];

function checkedUrl(value, protocols, origin) {
  const url = new URL(value, origin || document.baseURI);
  if (!protocols.includes(url.protocol) || (origin && url.origin !== origin)) {
    throw new Error("The application catalog contains an invalid URL.");
  }
  return url.href;
}

function validateDemo(demo) {
  if (!demo || typeof demo !== "object") {
    throw new Error("The application catalog contains an invalid entry.");
  }
  for (const field of catalogFields) {
    if (!(field in demo)) {
      throw new Error("The application catalog is missing required data.");
    }
  }
  for (const field of ["slug", "title", "description", "runtime", "entry_path", "docs_url", "source_url"]) {
    if (typeof demo[field] !== "string" || demo[field].length === 0) {
      throw new Error("The application catalog contains invalid text.");
    }
  }
  checkedUrl(demo.entry_path, ["http:", "https:"], window.location.origin);
  checkedUrl(demo.docs_url, ["https:"]);
  checkedUrl(demo.source_url, ["https:"]);
}

function newTabLink(label, href, context, className) {
  const link = document.createElement("a");
  link.className = className;
  link.href = href;
  link.target = "_blank";
  link.rel = "noopener noreferrer";

  const visibleLabel = document.createElement("span");
  visibleLabel.textContent = label;
  link.append(visibleLabel);

  const arrow = document.createElement("span");
  arrow.setAttribute("aria-hidden", "true");
  arrow.textContent = " ↗";
  link.append(arrow);

  const indication = document.createElement("span");
  indication.className = "visually-hidden";
  indication.textContent = ` ${context} (opens in a new tab)`;
  link.append(indication);

  return link;
}

function demoCard(demo) {
  const card = document.createElement("article");
  card.className = "demo-card";

  const headingRow = document.createElement("div");
  headingRow.className = "card-heading";

  const title = document.createElement("h3");
  title.textContent = demo.title;
  headingRow.append(title);

  const runtime = document.createElement("span");
  runtime.className = demo.runtime === "oxygen" ? "runtime runtime-oxygen" : "runtime";
  runtime.textContent = demo.runtime === "oxygen" ? "REST API" : "Interactive";
  headingRow.append(runtime);
  card.append(headingRow);

  const description = document.createElement("p");
  description.textContent = demo.description;
  card.append(description);

  const links = document.createElement("div");
  links.className = "card-links";
  links.append(
    newTabLink("Launch", checkedUrl(demo.entry_path, ["http:", "https:"], window.location.origin), demo.title, "button primary"),
    newTabLink("Documentation", checkedUrl(demo.docs_url, ["https:"]), demo.title, "button secondary"),
    newTabLink("Source", checkedUrl(demo.source_url, ["https:"]), demo.title, "text-link"),
  );
  card.append(links);

  return card;
}

async function loadCatalog() {
  const grid = document.querySelector("#demo-grid");
  try {
    const response = await fetch("./demos.json", { headers: { Accept: "application/json" } });
    if (!response.ok) {
      throw new Error(`Catalog request returned HTTP ${response.status}.`);
    }
    const demos = await response.json();
    if (!Array.isArray(demos) || demos.length === 0) {
      throw new Error("The application catalog is empty.");
    }
    demos.forEach(validateDemo);
    grid.replaceChildren(...demos.map(demoCard));
    grid.setAttribute("aria-busy", "false");
  } catch (error) {
    const message = document.createElement("p");
    message.className = "catalog-status error";
    message.setAttribute("role", "alert");
    message.textContent = "The application catalog could not be loaded. Please try again later.";
    grid.replaceChildren(message);
    grid.setAttribute("aria-busy", "false");
    console.error(error);
  }
}

document.querySelector("#skip-link").addEventListener("click", () => {
  document.querySelector("#demos").focus();
});

loadCatalog();
