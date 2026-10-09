#!/usr/bin/env node
// Captures one PNG of a page in headless Chrome over the DevTools protocol.
// Needs Node 22 or newer for the built-in WebSocket, and no npm packages.
//
//   node capture.mjs --url http://localhost:5302 --out after-canvas.png \
//     [--width 1440] [--height 900] [--scale 2] [--theme light|dark] \
//     [--wait-for <selector>] [--click <selector>] [--click-text <text>] [--eval <js>] \
//     [--delay <ms>] [--selector <selector>] [--chrome <path>]
//
// --click, --click-text, and --eval can repeat and run in the order given, after the
// page loads and --wait-for matches. --click-text clicks the innermost visible
// element whose text starts with the given text. --selector crops the image to one
// element.

import { spawn } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const DEFAULT_CHROME =
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const TIMEOUT_MS = 20000;

function parseArguments(argv) {
  const options = {
    width: 1440,
    height: 900,
    scale: 2,
    delay: 500,
    steps: [],
    chrome: process.env.CHROME_PATH || DEFAULT_CHROME,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const name = argv[index];
    const value = argv[index + 1];

    if (value === undefined) throw new Error(`${name} needs a value`);

    index += 1;

    if (name === "--click") options.steps.push({ click: value });
    else if (name === "--click-text") options.steps.push({ clickText: value });
    else if (name === "--eval") options.steps.push({ evaluate: value });
    else if (name === "--wait-for") options.waitFor = value;
    else if (["--width", "--height", "--scale", "--delay"].includes(name))
      options[name.slice(2)] = Number(value);
    else if (
      ["--url", "--out", "--theme", "--selector", "--chrome"].includes(name)
    )
      options[name.slice(2)] = value;
    else throw new Error(`Unknown option ${name}`);
  }

  if (!options.url || !options.out)
    throw new Error("--url and --out are required");

  return options;
}

function launchChrome(chrome, profile) {
  const child = spawn(
    chrome,
    [
      "--headless=new",
      "--remote-debugging-port=0",
      `--user-data-dir=${profile}`,
      "--no-first-run",
      "--no-default-browser-check",
      "--hide-scrollbars",
      "about:blank",
    ],
    { stdio: ["ignore", "ignore", "pipe"] },
  );

  const endpoint = new Promise((resolve, reject) => {
    let output = "";

    child.once("error", reject);
    child.once("exit", (code) =>
      reject(new Error(`Chrome exited with ${code}: ${output}`)),
    );
    child.stderr.on("data", (chunk) => {
      output += chunk.toString();

      const match = output.match(/DevTools listening on (ws:\/\/\S+)/);

      if (match) resolve(new URL(match[1]));
    });
  });

  return { child, endpoint };
}

async function connect(endpoint) {
  const targets = await fetch(`http://${endpoint.host}/json/list`).then(
    (response) => response.json(),
  );
  const page = targets.find((target) => target.type === "page");
  const socket = new WebSocket(page.webSocketDebuggerUrl);
  const pending = new Map();
  const listeners = new Set();
  let nextId = 1;

  await new Promise((resolve, reject) => {
    socket.addEventListener("open", resolve, { once: true });
    socket.addEventListener("error", reject, { once: true });
  });

  socket.addEventListener("message", (event) => {
    const message = JSON.parse(event.data);

    if (message.id && pending.has(message.id)) {
      const { resolve, reject } = pending.get(message.id);

      pending.delete(message.id);

      if (message.error) reject(new Error(message.error.message));
      else resolve(message.result);
    } else if (message.method) {
      for (const listener of listeners) listener(message);
    }
  });

  return {
    send(method, params = {}) {
      const id = nextId++;

      socket.send(JSON.stringify({ id, method, params }));

      return new Promise((resolve, reject) =>
        pending.set(id, { resolve, reject }),
      );
    },
    once(method) {
      return new Promise((resolve) => {
        const listener = (message) => {
          if (message.method !== method) return;

          listeners.delete(listener);
          resolve(message.params);
        };

        listeners.add(listener);
      });
    },
    close() {
      socket.close();
    },
  };
}

async function evaluate(session, expression) {
  const result = await session.send("Runtime.evaluate", {
    expression,
    awaitPromise: true,
    returnByValue: true,
    userGesture: true,
  });

  if (result.exceptionDetails)
    throw new Error(
      `${expression}: ${result.exceptionDetails.exception?.description ?? result.exceptionDetails.text}`,
    );

  return result.result.value;
}

async function waitFor(session, selector) {
  const deadline = Date.now() + TIMEOUT_MS;

  while (Date.now() < deadline) {
    if (
      await evaluate(
        session,
        `!!document.querySelector(${JSON.stringify(selector)})`,
      )
    )
      return;

    await new Promise((resolve) => setTimeout(resolve, 100));
  }

  throw new Error(`Timed out waiting for ${selector}`);
}

async function bounds(session, selector) {
  await waitFor(session, selector);

  return evaluate(
    session,
    `(() => {
      const rect = document.querySelector(${JSON.stringify(selector)}).getBoundingClientRect()
      return { x: rect.x, y: rect.y, width: rect.width, height: rect.height }
    })()`,
  );
}

async function click(session, selector) {
  const rect = await bounds(session, selector);
  const position = {
    x: rect.x + rect.width / 2,
    y: rect.y + rect.height / 2,
    button: "left",
    clickCount: 1,
  };

  await session.send("Input.dispatchMouseEvent", {
    ...position,
    type: "mouseMoved",
  });
  await session.send("Input.dispatchMouseEvent", {
    ...position,
    type: "mousePressed",
  });
  await session.send("Input.dispatchMouseEvent", {
    ...position,
    type: "mouseReleased",
  });
}

async function clickText(session, text) {
  const found = await evaluate(
    session,
    `(() => {
      const text = ${JSON.stringify(text)}
      const matches = [...document.querySelectorAll('body *')].filter(
        (element) => element.checkVisibility() && element.innerText?.trim().startsWith(text),
      )
      const innermost = matches.filter((element) => !matches.some((other) => other !== element && element.contains(other)))
      innermost[0]?.setAttribute('data-capture-target', '')
      return innermost.length > 0
    })()`,
  );

  if (!found)
    throw new Error(`No visible element starts with ${JSON.stringify(text)}`);

  await click(session, "[data-capture-target]");
  await evaluate(
    session,
    `document.querySelector('[data-capture-target]')?.removeAttribute('data-capture-target')`,
  );
}

async function capture(options) {
  const profile = mkdtempSync(join(tmpdir(), "pr-screenshots-"));
  const chrome = launchChrome(options.chrome, profile);

  try {
    const session = await connect(await chrome.endpoint);

    await session.send("Page.enable");
    await session.send("Emulation.setDeviceMetricsOverride", {
      width: options.width,
      height: options.height,
      deviceScaleFactor: options.scale,
      mobile: false,
    });

    if (options.theme) {
      await session.send("Emulation.setEmulatedMedia", {
        features: [{ name: "prefers-color-scheme", value: options.theme }],
      });
    }

    const loaded = session.once("Page.loadEventFired");

    await session.send("Page.navigate", { url: options.url });
    await loaded;

    if (options.waitFor) await waitFor(session, options.waitFor);

    for (const step of options.steps) {
      if (step.click) await click(session, step.click);
      else if (step.clickText) await clickText(session, step.clickText);
      else await evaluate(session, step.evaluate);

      await new Promise((resolve) => setTimeout(resolve, 150));
    }

    await new Promise((resolve) => setTimeout(resolve, options.delay));

    const clip = options.selector
      ? { ...(await bounds(session, options.selector)), scale: 1 }
      : undefined;
    const { data } = await session.send("Page.captureScreenshot", {
      format: "png",
      ...(clip ? { clip } : {}),
    });

    writeFileSync(options.out, Buffer.from(data, "base64"));
    session.close();
    console.log(options.out);
  } finally {
    if (chrome.child.exitCode === null) {
      const exited = new Promise((resolve) =>
        chrome.child.once("exit", resolve),
      );

      chrome.child.kill();
      await exited;
    }

    rmSync(profile, { recursive: true, force: true });
  }
}

capture(parseArguments(process.argv.slice(2))).catch((error) => {
  console.error(error.message);
  process.exit(1);
});
