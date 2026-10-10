#!/usr/bin/env node
// Captures one PNG of a page in headless Chrome over the DevTools protocol.
// Needs Node 22 or newer for the built-in WebSocket, and no npm packages.
//
//   node capture.mjs --url http://localhost:5302 --out after-canvas.png \
//     [--width 1440] [--height 900] [--scale 2] [--theme light|dark] \
//     [--wait-for <selector>] [--click <selector>] [--click-text <text>] \
//     [--right-click <selector>] [--middle-click <selector>] [--hover <selector>] \
//     [--pointer <x>,<y>[,idle|left|right|middle]] [--eval <js>] [--cursor on|off] \
//     [--delay <ms>] [--selector <selector>] [--padding <px>] [--chrome <path>]
//
// Steps (--click, --click-text, --right-click, --middle-click, --hover, --pointer, and
// --eval) can repeat and run in the order given, after the page loads and --wait-for
// matches. --click-text clicks the innermost visible element whose text starts with
// the given text. --pointer marks where an --eval step acted, without sending input.
//
// The last pointer step leaves a cursor in the image: a ring at the point and a mouse
// showing the pressed button, colored per button. It's drawn just before the capture
// and removed after, and skipped when the element it acted on is gone, such as a
// clicked menu item. --cursor off leaves it out.
//
// --selector crops the image to one element with --padding CSS pixels of the page
// around it, 32 by default, so shadows and nearby context stay in the frame. The crop
// grows to keep the cursor in it.

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
    padding: 32,
    cursor: "on",
    steps: [],
    chrome: process.env.CHROME_PATH || DEFAULT_CHROME,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const name = argv[index];
    const value = argv[index + 1];

    if (value === undefined) throw new Error(`${name} needs a value`);

    index += 1;

    if (name === "--click")
      options.steps.push({ pointer: value, button: "left" });
    else if (name === "--right-click")
      options.steps.push({ pointer: value, button: "right" });
    else if (name === "--middle-click")
      options.steps.push({ pointer: value, button: "middle" });
    else if (name === "--hover")
      options.steps.push({ pointer: value, button: "idle" });
    else if (name === "--pointer") options.steps.push({ mark: value });
    else if (name === "--click-text") options.steps.push({ clickText: value });
    else if (name === "--eval") options.steps.push({ evaluate: value });
    else if (name === "--wait-for") options.waitFor = value;
    else if (
      ["--width", "--height", "--scale", "--delay", "--padding"].includes(name)
    )
      options[name.slice(2)] = Number(value);
    else if (
      [
        "--url",
        "--out",
        "--theme",
        "--selector",
        "--chrome",
        "--cursor",
      ].includes(name)
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

async function paddedBounds(session, selector, padding) {
  const rect = await bounds(session, selector);
  const page = await evaluate(
    session,
    `({ width: document.documentElement.scrollWidth, height: document.documentElement.scrollHeight })`,
  );
  const x = Math.max(0, rect.x - padding);
  const y = Math.max(0, rect.y - padding);

  return {
    x,
    y,
    width: Math.min(page.width, rect.x + rect.width + padding) - x,
    height: Math.min(page.height, rect.y + rect.height + padding) - y,
  };
}

// Moves to the center of an element and presses `button` there, or only hovers for
// "idle". Returns where the pointer ended up and what it did.
async function point(session, selector, button) {
  const rect = await bounds(session, selector);
  const position = { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };

  await session.send("Input.dispatchMouseEvent", {
    ...position,
    type: "mouseMoved",
  });

  if (button !== "idle") {
    const press = { ...position, button, clickCount: 1 };

    await session.send("Input.dispatchMouseEvent", {
      ...press,
      type: "mousePressed",
    });
    await session.send("Input.dispatchMouseEvent", {
      ...press,
      type: "mouseReleased",
    });
  }

  return { ...position, button, target: { selector } };
}

// Whether what a pointer step acted on is still on the page. React may swap in a new
// element for the same thing, so this looks it up again instead of keeping the old one.
async function hasTarget(session, target) {
  if (target.text)
    return evaluate(
      session,
      `[...document.querySelectorAll('body *')].some(
        (element) => element.checkVisibility() && element.innerText?.trim().startsWith(${JSON.stringify(target.text)}),
      )`,
    );

  return evaluate(
    session,
    `!!document.querySelector(${JSON.stringify(target.selector)})?.checkVisibility()`,
  );
}

function parseMark(value) {
  const [x, y, button = "idle"] = value.split(",");

  if (!["idle", "left", "right", "middle"].includes(button))
    throw new Error(`Unknown pointer button ${button}`);

  return { x: Number(x), y: Number(y), button };
}

// The cursor box, in CSS pixels, with the point it marks CURSOR_TIP in from its corner.
// A ring marks the point, and a mouse showing the pressed button sits where an arrow
// cursor would, down and to the right of it. Each button has its own color.
const CURSOR_SIZE = 64;
const CURSOR_TIP = 30;
const CURSOR_COLORS = {
  idle: "#57606a",
  left: "#2f6fec",
  right: "#e8590c",
  middle: "#8250df",
};

function cursorSvg(button) {
  const color = CURSOR_COLORS[button];
  const pressed = {
    left: '<rect x="31" y="31" width="7" height="8" />',
    right: '<rect x="38" y="31" width="7" height="8" />',
    middle: '<rect x="36.5" y="32.5" width="3" height="6" rx="1.5" />',
  }[button];
  const ring =
    button === "idle"
      ? `<circle cx="30" cy="30" r="8" fill="none" stroke="${color}" stroke-width="2" />`
      : `<circle cx="30" cy="30" r="12" fill="${color}" fill-opacity="0.18" stroke="${color}" stroke-width="2" />`;

  return `<svg xmlns="http://www.w3.org/2000/svg" width="${CURSOR_SIZE}" height="${CURSOR_SIZE}" viewBox="0 0 ${CURSOR_SIZE} ${CURSOR_SIZE}">
    <defs><clipPath id="capture-mouse"><rect x="31" y="31" width="14" height="20" rx="7" /></clipPath></defs>
    ${ring}
    <rect x="31" y="31" width="14" height="20" rx="7" fill="white" />
    <g clip-path="url(#capture-mouse)" fill="${color}">${pressed ?? ""}</g>
    <path d="M38 31V39M31 39H45" stroke="#1b1f24" stroke-width="1" />
    <rect x="31" y="31" width="14" height="20" rx="7" fill="none" stroke="#1b1f24" stroke-width="1.5" />
  </svg>`;
}

async function showCursor(session, pointer) {
  await evaluate(
    session,
    `(() => {
      const cursor = document.createElement('div')
      cursor.id = 'capture-cursor'
      cursor.innerHTML = ${JSON.stringify(cursorSvg(pointer.button))}
      Object.assign(cursor.style, {
        position: 'fixed',
        left: '${pointer.x - CURSOR_TIP}px',
        top: '${pointer.y - CURSOR_TIP}px',
        width: '${CURSOR_SIZE}px',
        height: '${CURSOR_SIZE}px',
        zIndex: '2147483647',
        pointerEvents: 'none',
      })
      document.body.append(cursor)
    })()`,
  );
}

async function hideCursor(session) {
  await evaluate(
    session,
    `document.getElementById('capture-cursor')?.remove()`,
  );
}

// Grows a clip to cover the cursor drawn at `pointer`, with `margin` to spare.
function withCursor(clip, pointer, margin) {
  const cursorLeft = pointer.x - CURSOR_TIP - margin;
  const cursorTop = pointer.y - CURSOR_TIP - margin;
  const cursorEnd = CURSOR_SIZE + margin * 2;
  const left = Math.max(0, Math.min(clip.x, cursorLeft));
  const top = Math.max(0, Math.min(clip.y, cursorTop));
  const right = Math.max(clip.x + clip.width, cursorLeft + cursorEnd);
  const bottom = Math.max(clip.y + clip.height, cursorTop + cursorEnd);

  return { x: left, y: top, width: right - left, height: bottom - top };
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

  const pointer = {
    ...(await point(session, "[data-capture-target]", "left")),
    target: { text },
  };

  await evaluate(
    session,
    `document.querySelector('[data-capture-target]')?.removeAttribute('data-capture-target')`,
  );

  return pointer;
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

    let pointer;

    for (const step of options.steps) {
      if (step.pointer)
        pointer = await point(session, step.pointer, step.button);
      else if (step.mark) pointer = parseMark(step.mark);
      else if (step.clickText)
        pointer = await clickText(session, step.clickText);
      else await evaluate(session, step.evaluate);

      await new Promise((resolve) => setTimeout(resolve, 150));
    }

    await new Promise((resolve) => setTimeout(resolve, options.delay));

    // A click that removed its target, such as a menu item, leaves nothing to point at.
    const drawsCursor =
      pointer &&
      options.cursor !== "off" &&
      (!pointer.target || (await hasTarget(session, pointer.target)));
    let clip;

    if (options.selector) {
      const padded = await paddedBounds(
        session,
        options.selector,
        options.padding,
      );

      clip = {
        ...(drawsCursor
          ? withCursor(padded, pointer, Math.min(options.padding, 12))
          : padded),
        scale: 1,
      };
    }

    if (drawsCursor) await showCursor(session, pointer);

    const { data } = await session.send("Page.captureScreenshot", {
      format: "png",
      ...(clip ? { clip } : {}),
    });

    if (drawsCursor) await hideCursor(session);

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
