#!/usr/bin/env node
// Captures one PNG, or records one MP4, of a page in headless Chrome over the DevTools
// protocol. Needs Node 22 or newer for the built-in WebSocket, and no npm packages.
// Recording also needs ffmpeg with libx264.
//
//   node capture.mjs --url http://localhost:5302 --out after-canvas.png \
//     [--width 1440] [--height 900] [--scale 2] [--theme light|dark] \
//     [--appearance <theme>,<skin>|off] \
//     [--wait-for <selector>] [--click <target>] [--click-text <text>] \
//     [--right-click <target>] [--middle-click <target>] [--double-click <target>] \
//     [--hover <target>] \
//     [--drag <target>] [--drop <target>] [--key <keys>] [--type <text>] [--pause <ms>] \
//     [--caption <text>] \
//     [--pointer <x>,<y>[,idle|left|right|middle]] [--eval <js>] [--cursor on|off] \
//     [--delay <ms>] [--glide <ms>] [--selector <selector>] [--padding <px>] \
//     [--fps <n>] [--chrome <path>] [--ffmpeg <path>]
//
// Steps (--click, --click-text, --right-click, --middle-click, --double-click, --hover,
// --drag, --drop, --key, --type, --pause, --pointer, and --eval) can repeat and run in the order given,
// after the page loads and --wait-for matches. A <target> is a CSS selector, which the
// pointer acts on at its center, or an `<x>,<y>` point in CSS pixels. --click-text
// clicks the innermost visible element whose text starts with the given text. --drag
// presses the left button on its target, and --drop moves there with it held and lets
// go. --pause waits. --eval runs code in the page and prints what it returns. --pointer
// marks where an --eval step acted, without sending input.
//
// Page errors, console errors, and failed requests print to stderr as they happen.
//
// --caption shows a line of text at the top of the frame until the next --caption, or
// clears it when empty. Use it for what the page can't show, such as a CLI command
// run while recording.
//
// --key presses a key or shortcut as real input to whatever has focus, such as
// `Meta+C`, `Shift+Tab`, `Escape`, or `Delete`, with modifiers joined by `+`. --type
// types text into whatever has focus. Videos show each --key press in a badge at the
// bottom of the frame, so a shortcut reads as clearly as a click.
//
// The pointer glides to each target over --glide milliseconds, sending moves along the
// way, so hovers and drags behave as they would by hand.
//
// The last pointer step leaves a cursor in the image: a ring at the point and a mouse
// showing the pressed button, colored per button. It's drawn just before the capture
// and removed after, and skipped when the element it acted on is gone, such as a
// clicked menu item. --cursor off leaves it out.
//
// --selector crops the image to the elements it matches with --padding CSS pixels of
// the page around them, 32 by default, so shadows and nearby context stay in the
// frame. The crop grows to keep the cursor in it.
//
// --appearance pins Orion's theme and card skin, Vibrant and Trading cards unless
// given others, so captures from any branch render the same, even one from before
// they became the defaults. It sets them in browser storage before the page loads,
// over what the app's server has saved, and in a Storybook iframe's globals.
// --appearance off leaves the app to its saved choice or its own defaults.
//
// An --out ending in .mp4 records a video instead. Recording starts once --wait-for
// matches, runs through the steps, and stops --delay milliseconds after the last one.
// The cursor stays on screen the whole time and shows each press as it happens. For
// videos, --scale defaults to 1, --delay to 1500, and --glide to 600, and --selector
// crops to where the elements end up.

import { spawn } from "node:child_process";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const DEFAULT_CHROME =
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";
const TIMEOUT_MS = 20000;
const FRAME_MS = 16;

// How long to wait between steps, at the start of a video, and while a button is down
// on a click, so each action reads on its own in a video.
const STEP_MS = 150;
const VIDEO_STEP_MS = 450;
const VIDEO_LEAD_MS = 600;
const VIDEO_PRESS_MS = 220;
const DOUBLE_CLICK_MS = 60;

const SCREENSHOT_DEFAULTS = { scale: 2, delay: 500, glide: 120 };
const VIDEO_DEFAULTS = { scale: 1, delay: 1500, glide: 600 };

const VIDEO_KEY_MS = 900;
const VIDEO_TYPE_MS = 45;

const DEFAULT_APPEARANCE = "vibrant,trading";

const POINT_PATTERN = /^\s*(-?\d+(?:\.\d+)?)\s*,\s*(-?\d+(?:\.\d+)?)\s*$/;
const BUTTON_MASKS = { left: 1, right: 2, middle: 4 };

function parseArguments(argv) {
  const options = {
    width: 1440,
    height: 900,
    padding: 32,
    fps: 60,
    cursor: "on",
    appearance: DEFAULT_APPEARANCE,
    steps: [],
    chrome: process.env.CHROME_PATH || DEFAULT_CHROME,
    ffmpeg: process.env.FFMPEG_PATH || "ffmpeg",
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
    else if (name === "--double-click")
      options.steps.push({ pointer: value, button: "left", count: 2 });
    else if (name === "--hover")
      options.steps.push({ pointer: value, button: "idle" });
    else if (name === "--drag") options.steps.push({ drag: value });
    else if (name === "--drop") options.steps.push({ drop: value });
    else if (name === "--key") options.steps.push({ key: parseKeys(value) });
    else if (name === "--type") options.steps.push({ type: value });
    else if (name === "--caption") options.steps.push({ caption: value });
    else if (name === "--pause") options.steps.push({ pause: Number(value) });
    else if (name === "--pointer") options.steps.push({ mark: value });
    else if (name === "--click-text") options.steps.push({ clickText: value });
    else if (name === "--eval") options.steps.push({ evaluate: value });
    else if (name === "--wait-for") options.waitFor = value;
    else if (
      [
        "--width",
        "--height",
        "--scale",
        "--delay",
        "--glide",
        "--padding",
        "--fps",
      ].includes(name)
    )
      options[name.slice(2)] = Number(value);
    else if (
      [
        "--url",
        "--out",
        "--theme",
        "--selector",
        "--chrome",
        "--ffmpeg",
        "--cursor",
        "--appearance",
      ].includes(name)
    )
      options[name.slice(2)] = value;
    else throw new Error(`Unknown option ${name}`);
  }

  if (!options.url || !options.out)
    throw new Error("--url and --out are required");

  options.video = options.out.endsWith(".mp4");
  options.appearance = parseAppearance(options.appearance);

  return {
    ...(options.video ? VIDEO_DEFAULTS : SCREENSHOT_DEFAULTS),
    ...options,
  };
}

// Reads `<theme>,<skin>` into the ids Orion stores, or null for `off`.
function parseAppearance(value) {
  if (value === "off") return null;

  const [theme, skin] = value.split(",").map((part) => part.trim());

  if (!theme || !skin)
    throw new Error(`--appearance needs <theme>,<skin> or off, not ${value}`);

  return { theme, skin };
}

// Pins the theme and skin in every document the page loads. Browser storage covers the
// first paint, the saved-settings response covers the app's restore from its server,
// which would otherwise overwrite storage, and the URL covers Storybook, whose
// toolbar globals drive most stories.
async function pinAppearance(session, appearance) {
  await session.send("Page.addScriptToEvaluateOnNewDocument", {
    source: `try {
      localStorage.setItem("orion:theme", ${JSON.stringify(appearance.theme)});
      localStorage.setItem("orion:skin", ${JSON.stringify(appearance.skin)});
    } catch {}`,
  });

  session.on("Fetch.requestPaused", (params) =>
    pinSavedSettings(session, appearance, params).catch((error) => {
      console.error(`--appearance: ${error.message}`);
      session.send("Fetch.continueRequest", { requestId: params.requestId });
    }),
  );
  await session.send("Fetch.enable", {
    patterns: [{ urlPattern: "*/api/settings", requestStage: "Response" }],
  });
}

async function pinSavedSettings(session, appearance, params) {
  const { requestId, request, responseStatusCode, responseHeaders } = params;

  if (request.method !== "GET" || responseStatusCode !== 200) {
    await session.send("Fetch.continueRequest", { requestId });

    return;
  }

  const { body, base64Encoded } = await session.send("Fetch.getResponseBody", {
    requestId,
  });
  const saved = JSON.parse(
    base64Encoded ? Buffer.from(body, "base64").toString() : body,
  );

  await session.send("Fetch.fulfillRequest", {
    requestId,
    responseCode: 200,
    responseHeaders: responseHeaders.filter(
      ({ name }) => name.toLowerCase() !== "content-length",
    ),
    body: Buffer.from(
      JSON.stringify({
        ...saved,
        theme: appearance.theme,
        skin: appearance.skin,
      }),
    ).toString("base64"),
  });
}

// A Storybook iframe takes its toolbar globals from the URL. One the URL already sets
// wins.
function withStoryGlobals(url, appearance) {
  const parsed = new URL(url);

  if (!parsed.pathname.endsWith("/iframe.html")) return url;

  const globals = new Map(
    (parsed.searchParams.get("globals") ?? "")
      .split(";")
      .filter(Boolean)
      .map((pair) => pair.split(":")),
  );

  if (!globals.has("theme")) globals.set("theme", appearance.theme);
  if (!globals.has("skin")) globals.set("skin", appearance.skin);

  parsed.searchParams.set(
    "globals",
    [...globals].map((pair) => pair.join(":")).join(";"),
  );

  return parsed.toString();
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

// Chrome renders at `scale` itself, not only through emulation, because the screencast
// sends frames no larger than the window's own pixels.
function launchChrome(chrome, profile, scale) {
  const child = spawn(
    chrome,
    [
      "--headless=new",
      "--remote-debugging-port=0",
      `--user-data-dir=${profile}`,
      "--no-first-run",
      "--no-default-browser-check",
      "--hide-scrollbars",
      `--force-device-scale-factor=${scale}`,
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
    // Calls `callback` with each event of `method` until the returned function is called.
    on(method, callback) {
      const listener = (message) => {
        if (message.method === method) callback(message.params);
      };

      listeners.add(listener);

      return () => listeners.delete(listener);
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

    await sleep(100);
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

// The box around every element the selector matches that takes up space, so
// `.react-flow__node` frames all the cards on the canvas.
async function unionBounds(session, selector) {
  await waitFor(session, selector);

  return evaluate(
    session,
    `(() => {
      const rects = [...document.querySelectorAll(${JSON.stringify(selector)})].map((element) =>
        element.getBoundingClientRect()
      ).filter((rect) => rect.width > 0 || rect.height > 0)
      const x = Math.min(...rects.map((rect) => rect.left))
      const y = Math.min(...rects.map((rect) => rect.top))
      return {
        x,
        y,
        width: Math.max(...rects.map((rect) => rect.right)) - x,
        height: Math.max(...rects.map((rect) => rect.bottom)) - y,
      }
    })()`,
  );
}

async function paddedBounds(session, selector, padding) {
  const rect = await unionBounds(session, selector);
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

// Where a step's target is: the point it names, or the center of the element its
// selector matches, along with what to look for later to tell whether it's still there.
async function locate(session, target) {
  const match = target.match(POINT_PATTERN);

  if (match) return { x: Number(match[1]), y: Number(match[2]) };

  const rect = await bounds(session, target);

  return {
    x: rect.x + rect.width / 2,
    y: rect.y + rect.height / 2,
    target: { selector: target },
  };
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

// Draws the cursor at `pointer`, adding it on first use and moving it after that. The
// drawing only changes when the button does, so moving it each frame stays cheap.
async function drawCursor(session, pointer) {
  await evaluate(
    session,
    `(() => {
      let cursor = document.getElementById('capture-cursor')
      if (!cursor) {
        cursor = document.createElement('div')
        cursor.id = 'capture-cursor'
        Object.assign(cursor.style, {
          position: 'fixed',
          width: '${CURSOR_SIZE}px',
          height: '${CURSOR_SIZE}px',
          zIndex: '2147483647',
          pointerEvents: 'none',
        })
        document.body.append(cursor)
      }
      if (cursor.dataset.button !== '${pointer.button}') {
        cursor.dataset.button = '${pointer.button}'
        cursor.innerHTML = ${JSON.stringify(cursorSvg(pointer.button))}
      }
      cursor.style.left = '${pointer.x - CURSOR_TIP}px'
      cursor.style.top = '${pointer.y - CURSOR_TIP}px'
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

function easeInOut(progress) {
  return progress < 0.5 ? 4 * progress ** 3 : 1 - (-2 * progress + 2) ** 3 / 2;
}

// The mouse, which knows where it is, which button it holds, and whether it draws its
// cursor as it goes. Videos draw it throughout; screenshots draw it once at the end.
function createMouse(session, options) {
  const mouse = {
    x: options.width / 2,
    y: options.height / 2,
    button: "idle",
    held: undefined,
    drawn: options.video && options.cursor !== "off",
  };

  function dispatch(type, extra = {}) {
    return session.send("Input.dispatchMouseEvent", {
      type,
      x: mouse.x,
      y: mouse.y,
      ...(mouse.held
        ? { button: mouse.held, buttons: BUTTON_MASKS[mouse.held] }
        : {}),
      ...extra,
    });
  }

  async function redraw() {
    if (mouse.drawn) await drawCursor(session, mouse);
  }

  return {
    state: mouse,
    redraw,

    // Glides to `position` over --glide milliseconds, sending a move each frame unless
    // `input` is false, which moves only the drawn cursor. Progress follows the clock,
    // so slow round trips to Chrome drop frames instead of stretching the glide.
    async moveTo(position, { input = true } = {}) {
      const start = { x: mouse.x, y: mouse.y };
      const startedAt = Date.now();
      let progress = 0;

      while (progress < 1) {
        progress =
          options.glide > 0
            ? Math.min(1, (Date.now() - startedAt) / options.glide)
            : 1;

        const eased = easeInOut(progress);

        mouse.x = start.x + (position.x - start.x) * eased;
        mouse.y = start.y + (position.y - start.y) * eased;

        if (input) await dispatch("mouseMoved");

        await redraw();

        if (progress < 1) await sleep(FRAME_MS);
      }
    },

    async press(button, clickCount = 1) {
      mouse.held = button;
      mouse.button = button;

      await dispatch("mousePressed", { clickCount });
      await redraw();
    },

    async release(clickCount = 1) {
      const button = mouse.held;

      mouse.held = undefined;

      await dispatch("mouseReleased", { button, buttons: 0, clickCount });
    },

    // Shows the cursor back at rest after a press, in videos only. Screenshots keep the
    // last button pressed so the image shows what happened.
    async settle() {
      if (!mouse.drawn) return;

      await sleep(VIDEO_PRESS_MS);
      mouse.button = "idle";
      await redraw();
    },

    // Clicks `count` times in a row, so 2 is a double click. Videos hold a single click
    // long enough to see, and keep a double click's presses quick enough to count.
    async click(button, count = 1) {
      for (let clickCount = 1; clickCount <= count; clickCount += 1) {
        await this.press(button, clickCount);

        if (mouse.drawn)
          await sleep(count > 1 ? DOUBLE_CLICK_MS : VIDEO_PRESS_MS);

        await this.release(clickCount);

        if (clickCount < count) await sleep(DOUBLE_CLICK_MS);
      }

      await this.settle();
    },
  };
}

// Modifier keys by the names --key accepts, with their DevTools bit, key name, and
// the symbol the video badge shows.
const MODIFIERS = {
  alt: { bit: 1, key: "Alt", code: "AltLeft", keyCode: 18, symbol: "⌥" },
  option: { bit: 1, key: "Alt", code: "AltLeft", keyCode: 18, symbol: "⌥" },
  control: {
    bit: 2,
    key: "Control",
    code: "ControlLeft",
    keyCode: 17,
    symbol: "⌃",
  },
  ctrl: {
    bit: 2,
    key: "Control",
    code: "ControlLeft",
    keyCode: 17,
    symbol: "⌃",
  },
  meta: { bit: 4, key: "Meta", code: "MetaLeft", keyCode: 91, symbol: "⌘" },
  cmd: { bit: 4, key: "Meta", code: "MetaLeft", keyCode: 91, symbol: "⌘" },
  command: { bit: 4, key: "Meta", code: "MetaLeft", keyCode: 91, symbol: "⌘" },
  shift: { bit: 8, key: "Shift", code: "ShiftLeft", keyCode: 16, symbol: "⇧" },
};

// Keys that don't type a character, by the names --key accepts.
const NAMED_KEYS = {
  enter: { key: "Enter", code: "Enter", keyCode: 13, symbol: "↩", text: "\r" },
  escape: { key: "Escape", code: "Escape", keyCode: 27, symbol: "esc" },
  esc: { key: "Escape", code: "Escape", keyCode: 27, symbol: "esc" },
  tab: { key: "Tab", code: "Tab", keyCode: 9, symbol: "⇥" },
  backspace: { key: "Backspace", code: "Backspace", keyCode: 8, symbol: "⌫" },
  delete: { key: "Delete", code: "Delete", keyCode: 46, symbol: "⌦" },
  space: { key: " ", code: "Space", keyCode: 32, symbol: "Space", text: " " },
  arrowup: { key: "ArrowUp", code: "ArrowUp", keyCode: 38, symbol: "↑" },
  arrowdown: { key: "ArrowDown", code: "ArrowDown", keyCode: 40, symbol: "↓" },
  arrowleft: { key: "ArrowLeft", code: "ArrowLeft", keyCode: 37, symbol: "←" },
  arrowright: {
    key: "ArrowRight",
    code: "ArrowRight",
    keyCode: 39,
    symbol: "→",
  },
  home: { key: "Home", code: "Home", keyCode: 36, symbol: "Home" },
  end: { key: "End", code: "End", keyCode: 35, symbol: "End" },
  pageup: { key: "PageUp", code: "PageUp", keyCode: 33, symbol: "PgUp" },
  pagedown: { key: "PageDown", code: "PageDown", keyCode: 34, symbol: "PgDn" },
};

// Editing commands Chrome runs for Mac shortcuts in a real window but not headless,
// keyed by the shortcut with Meta, and Shift when it's held.
const EDITING_COMMANDS = {
  "Meta+a": "selectAll",
  "Meta+c": "copy",
  "Meta+x": "cut",
  "Meta+v": "paste",
  "Meta+z": "undo",
  "Meta+Shift+z": "redo",
};

// Punctuation keys on a US layout, so shortcuts such as `Meta+[` carry the code apps
// match on.
const PUNCTUATION_KEYS = {
  "[": { code: "BracketLeft", keyCode: 219 },
  "]": { code: "BracketRight", keyCode: 221 },
  ",": { code: "Comma", keyCode: 188 },
  ".": { code: "Period", keyCode: 190 },
  "/": { code: "Slash", keyCode: 191 },
  "\\": { code: "Backslash", keyCode: 220 },
  ";": { code: "Semicolon", keyCode: 186 },
  "'": { code: "Quote", keyCode: 222 },
  "`": { code: "Backquote", keyCode: 192 },
  "-": { code: "Minus", keyCode: 189 },
  "=": { code: "Equal", keyCode: 187 },
};

function describeCharacter(character) {
  const upper = character.toUpperCase();

  if (/^[a-z]$/i.test(character))
    return {
      key: character.toLowerCase(),
      code: `Key${upper}`,
      keyCode: upper.charCodeAt(0),
      symbol: upper,
      text: character.toLowerCase(),
    };

  if (/^[0-9]$/.test(character))
    return {
      key: character,
      code: `Digit${character}`,
      keyCode: character.charCodeAt(0),
      symbol: character,
      text: character,
    };

  const punctuation = PUNCTUATION_KEYS[character];

  return {
    key: character,
    code: punctuation?.code,
    keyCode: punctuation?.keyCode ?? 0,
    symbol: character,
    text: character,
  };
}

// Splits a shortcut such as `Meta+Shift+Z` into its modifiers and the key they modify.
function parseKeys(value) {
  const parts = value.split(/\+(?!$)/);
  const name = parts.pop();
  const modifiers = parts.map((part) => {
    const modifier = MODIFIERS[part.toLowerCase()];

    if (!modifier) throw new Error(`Unknown modifier ${part} in ${value}`);

    return modifier;
  });
  const key =
    MODIFIERS[name.toLowerCase()] ??
    NAMED_KEYS[name.toLowerCase()] ??
    (name.length === 1 ? describeCharacter(name) : undefined);

  if (!key) throw new Error(`Unknown key ${name} in ${value}`);

  return { modifiers, key };
}

// Draws a badge with the keys just pressed at the bottom of the frame, replacing any
// badge still showing.
async function showKeys(session, keys) {
  const label = [...keys.modifiers, keys.key]
    .map((key) => key.symbol)
    .join(" ");

  await evaluate(
    session,
    `(() => {
      document.getElementById('capture-keys')?.remove()
      const badge = document.createElement('div')
      badge.id = 'capture-keys'
      badge.textContent = ${JSON.stringify(label)}
      Object.assign(badge.style, {
        position: 'fixed',
        left: '50%',
        bottom: '72px',
        transform: 'translateX(-50%)',
        padding: '10px 18px',
        borderRadius: '12px',
        background: 'rgba(27, 31, 36, 0.88)',
        color: '#f6f8fa',
        font: '600 24px -apple-system, system-ui, sans-serif',
        letterSpacing: '0.08em',
        zIndex: '2147483647',
        pointerEvents: 'none',
      })
      document.body.append(badge)
    })()`,
  );
}

// Shows `text` in a bar at the top of the frame, replacing any caption already there, or
// clears the caption when `text` is empty.
async function showCaption(session, text) {
  await evaluate(
    session,
    `(() => {
      document.getElementById('capture-caption')?.remove()
      if (!${JSON.stringify(text)}) return
      const caption = document.createElement('div')
      caption.id = 'capture-caption'
      caption.textContent = ${JSON.stringify(text)}
      Object.assign(caption.style, {
        position: 'fixed',
        left: '50%',
        top: '20px',
        transform: 'translateX(-50%)',
        maxWidth: '70%',
        padding: '10px 18px',
        borderRadius: '12px',
        background: 'rgba(27, 31, 36, 0.88)',
        color: '#f6f8fa',
        font: '500 20px ui-monospace, SFMono-Regular, Menlo, monospace',
        zIndex: '2147483647',
        pointerEvents: 'none',
      })
      document.body.append(caption)
    })()`,
  );
}

async function hideKeys(session) {
  await evaluate(session, `document.getElementById('capture-keys')?.remove()`);
}

// Presses `keys` as real keyboard input: modifiers down, the key down and up, then the
// modifiers up. A character key types only without Control, Alt, or Meta, as on a Mac.
async function pressKeys(session, keys, options) {
  let modifierBits = 0;

  for (const modifier of keys.modifiers) {
    modifierBits |= modifier.bit;

    await session.send("Input.dispatchKeyEvent", {
      type: "rawKeyDown",
      modifiers: modifierBits,
      key: modifier.key,
      code: modifier.code,
      windowsVirtualKeyCode: modifier.keyCode,
    });
  }

  const types = (modifierBits & 7) === 0 && keys.key.text;
  const command =
    modifierBits === 4 || modifierBits === 12
      ? EDITING_COMMANDS[
          `Meta+${modifierBits & 8 ? "Shift+" : ""}${keys.key.key.toLowerCase()}`
        ]
      : undefined;
  const event = {
    modifiers: modifierBits,
    key:
      modifierBits & 8 && keys.key.text?.length === 1
        ? keys.key.key.toUpperCase()
        : keys.key.key,
    code: keys.key.code,
    windowsVirtualKeyCode: keys.key.keyCode,
  };

  if (options.video) await showKeys(session, keys);

  await session.send("Input.dispatchKeyEvent", {
    ...event,
    type: types ? "keyDown" : "rawKeyDown",
    ...(command ? { commands: [command] } : {}),
    ...(types
      ? { text: modifierBits & 8 ? keys.key.text.toUpperCase() : keys.key.text }
      : {}),
  });
  await session.send("Input.dispatchKeyEvent", { ...event, type: "keyUp" });

  for (const modifier of keys.modifiers.toReversed()) {
    modifierBits &= ~modifier.bit;

    await session.send("Input.dispatchKeyEvent", {
      type: "keyUp",
      modifiers: modifierBits,
      key: modifier.key,
      code: modifier.code,
      windowsVirtualKeyCode: modifier.keyCode,
    });
  }

  if (options.video) {
    await sleep(VIDEO_KEY_MS);
    await hideKeys(session);
  }
}

// Types `text` a character at a time, slowly enough in videos to read as typing.
async function typeText(session, text, options) {
  for (const character of text) {
    await session.send("Input.insertText", { text: character });

    if (options.video) await sleep(VIDEO_TYPE_MS);
  }
}

// Marks the innermost visible element whose text starts with `text` so a selector can
// find it, and returns a function that clears the mark.
async function markText(session, text) {
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

  return () =>
    evaluate(
      session,
      `document.querySelector('[data-capture-target]')?.removeAttribute('data-capture-target')`,
    );
}

// Runs one step and returns where the pointer acted and with which button, or nothing
// for steps that don't move it.
async function runStep(session, mouse, step, options) {
  if (step.pointer || step.clickText) {
    const clear = step.clickText && (await markText(session, step.clickText));
    const position = await locate(
      session,
      step.pointer ?? "[data-capture-target]",
    );
    const button = step.button ?? "left";

    await mouse.moveTo(position);

    if (button !== "idle") await mouse.click(button, step.count);

    if (clear) {
      await clear();
      position.target = { text: step.clickText };
    }

    return { ...position, button };
  }

  if (step.drag) {
    const position = await locate(session, step.drag);

    await mouse.moveTo(position);
    await mouse.press("left");

    return { ...position, button: "left" };
  }

  if (step.drop) {
    if (!mouse.state.held) throw new Error("--drop needs a --drag before it");

    const position = await locate(session, step.drop);

    await mouse.moveTo(position);
    await mouse.release();
    await mouse.settle();

    return { ...position, button: "left" };
  }

  if (step.mark) {
    const mark = parseMark(step.mark);

    await mouse.moveTo(mark, { input: false });

    if (mark.button !== "idle") {
      mouse.state.button = mark.button;
      await mouse.redraw();
      await mouse.settle();
    }

    return mark;
  }

  if (step.key) await pressKeys(session, step.key, options);
  else if (step.caption !== undefined) await showCaption(session, step.caption);
  else if (step.type !== undefined) await typeText(session, step.type, options);
  else if (step.pause !== undefined) await sleep(step.pause);
  else {
    const value = await evaluate(session, step.evaluate);

    if (value !== undefined)
      console.log(`--eval ${step.evaluate}\n${JSON.stringify(value, null, 2)}`);
  }
}

// Reports what the page doesn't show: uncaught errors, console errors, and requests
// that fail. A step can look like it did nothing because the app hit one of these,
// such as a server too old for the app sending it requests.
async function watchPage(session) {
  session.on("Runtime.exceptionThrown", ({ exceptionDetails }) =>
    console.error(
      `page error: ${exceptionDetails.exception?.description ?? exceptionDetails.text}`,
    ),
  );
  session.on("Runtime.consoleAPICalled", ({ type, args }) => {
    if (type !== "error") return;

    console.error(
      `console error: ${args.map((arg) => arg.value ?? arg.description).join(" ")}`,
    );
  });
  session.on("Network.responseReceived", ({ response }) => {
    if (response.status >= 400 && !response.url.endsWith("/favicon.ico"))
      console.error(`request failed: ${response.status} ${response.url}`);
  });
  session.on("Network.loadingFailed", ({ errorText, canceled }) => {
    if (!canceled) console.error(`request failed: ${errorText}`);
  });

  await session.send("Runtime.enable");
  await session.send("Network.enable");
}

// Streams frames from Chrome into `directory` as JPEGs until stopped. Chrome sends a
// frame only when the page repaints, so each one records when it was shown.
async function startRecording(session, directory, options) {
  const frames = [];
  const stopListening = session.on("Page.screencastFrame", (params) => {
    const file = join(
      directory,
      `${String(frames.length).padStart(6, "0")}.jpg`,
    );

    writeFileSync(file, Buffer.from(params.data, "base64"));
    frames.push({
      file,
      shownAt: params.metadata.timestamp,
      arrivedAt: Date.now(),
    });
    session.send("Page.screencastFrameAck", { sessionId: params.sessionId });
  });

  await session.send("Page.startScreencast", {
    format: "jpeg",
    quality: 95,
    maxWidth: Math.round(options.width * options.scale),
    maxHeight: Math.round(options.height * options.scale),
    everyNthFrame: 1,
  });

  return {
    frames,
    async stop() {
      const stoppedAt = Date.now();

      await session.send("Page.stopScreencast");
      stopListening();

      return stoppedAt;
    },
  };
}

// Encodes recorded frames into an H.264 MP4 at a steady frame rate, holding each frame
// until the next one, and the last until recording stopped. `clip` crops, in CSS pixels.
async function encodeVideo(frames, stoppedAt, directory, options, clip) {
  if (frames.length === 0) throw new Error("Chrome sent no frames to record");

  const lines = ["ffconcat version 1.0"];

  frames.forEach((frame, index) => {
    const next = frames[index + 1];
    const seconds = next
      ? next.shownAt - frame.shownAt
      : (stoppedAt - frame.arrivedAt) / 1000;

    lines.push(`file '${frame.file}'`, `duration ${Math.max(seconds, 0.001)}`);
  });
  lines.push(`file '${frames.at(-1).file}'`);

  const list = join(directory, "frames.txt");
  const filters = [];

  writeFileSync(list, `${lines.join("\n")}\n`);

  // Scale the crop by the frames' own size, since Chrome can send frames smaller than
  // the viewport at --scale.
  if (clip) {
    const across = (value) => `${value}*iw/${options.width}`;
    const down = (value) => `${value}*ih/${options.height}`;

    filters.push(
      `crop=${[across(clip.width), down(clip.height), across(clip.x), down(clip.y)].join(":")}`,
    );
  }

  filters.push("crop=trunc(iw/2)*2:trunc(ih/2)*2:0:0", "format=yuv420p");

  await run(options.ffmpeg, [
    "-y",
    "-f",
    "concat",
    "-safe",
    "0",
    "-i",
    list,
    "-vf",
    filters.join(","),
    "-fps_mode",
    "cfr",
    "-r",
    String(options.fps),
    "-c:v",
    "libx264",
    "-preset",
    "slow",
    "-crf",
    "20",
    "-movflags",
    "+faststart",
    "-an",
    options.out,
  ]);
}

// Runs a command to completion, rejecting with the end of its error output on failure.
function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: ["ignore", "ignore", "pipe"] });
    let output = "";

    child.stderr.on("data", (chunk) => {
      output += chunk.toString();
    });
    child.once("error", reject);
    child.once("exit", (code) => {
      if (code === 0) resolve();
      else
        reject(
          new Error(`${command} exited with ${code}: ${output.slice(-2000)}`),
        );
    });
  });
}

async function screenshot(session, options, pointer) {
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

  if (drawsCursor) await drawCursor(session, pointer);

  const { data } = await session.send("Page.captureScreenshot", {
    format: "png",
    ...(clip ? { clip } : {}),
  });

  if (drawsCursor) await hideCursor(session);

  writeFileSync(options.out, Buffer.from(data, "base64"));
}

async function capture(options) {
  const profile = mkdtempSync(join(tmpdir(), "pr-screenshots-"));
  const frames = options.video
    ? mkdtempSync(join(tmpdir(), "pr-videos-"))
    : undefined;
  const chrome = launchChrome(options.chrome, profile, options.scale);

  try {
    const session = await connect(await chrome.endpoint);

    await session.send("Page.enable");
    await watchPage(session);
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

    if (options.appearance) await pinAppearance(session, options.appearance);

    const loaded = session.once("Page.loadEventFired");

    await session.send("Page.navigate", {
      url: options.appearance
        ? withStoryGlobals(options.url, options.appearance)
        : options.url,
    });
    await loaded;

    if (options.waitFor) await waitFor(session, options.waitFor);

    const mouse = createMouse(session, options);
    let recording;

    if (options.video) {
      recording = await startRecording(session, frames, options);

      await mouse.redraw();
      await sleep(VIDEO_LEAD_MS);
    }

    let pointer;

    for (const step of options.steps) {
      pointer = (await runStep(session, mouse, step, options)) ?? pointer;

      await sleep(options.video ? VIDEO_STEP_MS : STEP_MS);
    }

    await sleep(options.delay);

    if (options.video) {
      const clip =
        options.selector &&
        (await paddedBounds(session, options.selector, options.padding));
      const stoppedAt = await recording.stop();

      await encodeVideo(recording.frames, stoppedAt, frames, options, clip);
    } else {
      await screenshot(session, options, pointer);
    }

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

    if (frames) rmSync(frames, { recursive: true, force: true });
  }
}

capture(parseArguments(process.argv.slice(2))).catch((error) => {
  console.error(error.message);
  process.exit(1);
});
