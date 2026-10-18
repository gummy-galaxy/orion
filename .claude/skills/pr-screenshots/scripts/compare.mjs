#!/usr/bin/env node
// Puts a before and an after video in one MP4, playing together, each under a label.
// Needs Node 22 or newer, ffmpeg with libx264 and ffprobe, and Chrome to draw the labels.
//
//   node compare.mjs --before before-drag.mp4 --after after-drag.mp4 \
//     --out compare-drag.mp4 [--layout stacked|side] [--labels Before,After|off] \
//     [--chrome <path>] [--ffmpeg <path>] [--ffprobe <path>]
//
// --layout stacked, the default, puts after below before, which suits the narrow column
// of a pull request description. --layout side puts them next to each other. The after
// video is scaled to match the before video's width when stacked, or its height side
// by side. The shorter one holds its last frame until the longer one ends.

import { spawn } from "node:child_process";
import { mkdtempSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

const DEFAULT_CHROME =
  "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome";

// Label bars are this tall, as a share of the width of the panel they head, with
// FONT_SHARE of that height for the text.
const LABEL_SHARE = 0.04;
const FONT_SHARE = 0.42;

function parseArguments(argv) {
  const options = {
    layout: "stacked",
    labels: "Before,After",
    chrome: process.env.CHROME_PATH || DEFAULT_CHROME,
    ffmpeg: process.env.FFMPEG_PATH || "ffmpeg",
    ffprobe: process.env.FFPROBE_PATH || "ffprobe",
  };

  for (let index = 0; index < argv.length; index += 2) {
    const name = argv[index];
    const value = argv[index + 1];

    if (value === undefined) throw new Error(`${name} needs a value`);

    if (
      [
        "--before",
        "--after",
        "--out",
        "--layout",
        "--labels",
        "--chrome",
        "--ffmpeg",
        "--ffprobe",
      ].includes(name)
    )
      options[name.slice(2)] = value;
    else throw new Error(`Unknown option ${name}`);
  }

  if (!options.before || !options.after || !options.out)
    throw new Error("--before, --after, and --out are required");

  if (!["stacked", "side"].includes(options.layout))
    throw new Error(`Unknown layout ${options.layout}`);

  return options;
}

// Runs a command to completion and resolves with its output, rejecting with the end of
// its error output on failure.
function run(command, args) {
  return new Promise((resolve, reject) => {
    const child = spawn(command, args, { stdio: ["ignore", "pipe", "pipe"] });
    let output = "";
    let errors = "";

    child.stdout.on("data", (chunk) => {
      output += chunk.toString();
    });
    child.stderr.on("data", (chunk) => {
      errors += chunk.toString();
    });
    child.once("error", reject);
    child.once("exit", (code) => {
      if (code === 0) resolve(output);
      else
        reject(
          new Error(`${command} exited with ${code}: ${errors.slice(-2000)}`),
        );
    });
  });
}

async function probe(ffprobe, file) {
  const output = await run(ffprobe, [
    "-v",
    "error",
    "-select_streams",
    "v:0",
    "-show_entries",
    "stream=width,height:format=duration",
    "-of",
    "json",
    file,
  ]);
  const { streams, format } = JSON.parse(output);

  return {
    width: streams[0].width,
    height: streams[0].height,
    duration: Number(format.duration),
  };
}

function even(value) {
  return Math.round(value / 2) * 2;
}

// Draws a label bar as a PNG with Chrome's own screenshot flag, since ffmpeg builds
// often lack the libraries its text filter needs.
async function drawLabel(chrome, text, width, height, file) {
  const profile = mkdtempSync(join(tmpdir(), "pr-videos-label-"));
  const fontSize = Math.round(height * FONT_SHARE);
  const html = `<!doctype html><body style="margin:0;height:${height}px;display:flex;align-items:center;padding:0 ${fontSize}px;background:#1b1f24;color:#f6f8fa;font:600 ${fontSize}px -apple-system,system-ui,sans-serif">${text}</body>`;

  try {
    await run(chrome, [
      "--headless=new",
      `--user-data-dir=${profile}`,
      "--no-first-run",
      "--hide-scrollbars",
      "--force-device-scale-factor=1",
      `--window-size=${width},${height}`,
      `--screenshot=${file}`,
      `data:text/html,${encodeURIComponent(html)}`,
    ]);
  } finally {
    rmSync(profile, { recursive: true, force: true });
  }
}

async function compare(options) {
  const before = await probe(options.ffprobe, options.before);
  const after = await probe(options.ffprobe, options.after);
  const stacked = options.layout === "stacked";
  const duration = Math.max(before.duration, after.duration);

  // Both panels share the before video's width when stacked, or its height side by side.
  const panels = [before, after].map((video) =>
    stacked
      ? {
          width: before.width,
          height: even((video.height * before.width) / video.width),
        }
      : {
          width: even((video.width * before.height) / video.height),
          height: before.height,
        },
  );
  const labels =
    options.labels === "off" ? undefined : options.labels.split(",");
  const directory = mkdtempSync(join(tmpdir(), "pr-videos-compare-"));

  try {
    const inputs = ["-i", options.before, "-i", options.after];
    const filters = [];

    panels.forEach((panel, index) => {
      const pad = duration - [before, after][index].duration;

      filters.push(
        `[${index}:v]scale=${panel.width}:${panel.height},setsar=1,fps=60,tpad=stop_mode=clone:stop_duration=${pad + 0.1},format=yuv420p[video${index}]`,
      );
    });

    if (labels) {
      for (const [index, panel] of panels.entries()) {
        const file = join(directory, `label-${index}.png`);
        const height = even(panel.width * LABEL_SHARE);

        await drawLabel(
          options.chrome,
          labels[index],
          panel.width,
          height,
          file,
        );
        inputs.push("-loop", "1", "-i", file);
        filters.push(
          `[${index + 2}:v]scale=${panel.width}:${height},setsar=1,fps=60,format=yuv420p[label${index}]`,
          `[label${index}][video${index}]vstack=shortest=1[panel${index}]`,
        );
      }
    } else {
      filters.push("[video0]null[panel0]", "[video1]null[panel1]");
    }

    if (stacked) filters.push("[panel0][panel1]vstack[out]");
    else
      filters.push(
        // Side by side, the panels may differ in height once labels are added, so the
        // shorter one is padded at the bottom.
        "[panel0][panel1]xstack=inputs=2:layout=0_0|w0_0:fill=black[out]",
      );

    await run(options.ffmpeg, [
      "-y",
      ...inputs,
      "-filter_complex",
      filters.join(";"),
      "-map",
      "[out]",
      "-t",
      String(duration),
      "-c:v",
      "libx264",
      "-preset",
      "slow",
      "-crf",
      "20",
      "-pix_fmt",
      "yuv420p",
      "-movflags",
      "+faststart",
      "-an",
      options.out,
    ]);

    console.log(options.out);
  } finally {
    rmSync(directory, { recursive: true, force: true });
  }
}

compare(parseArguments(process.argv.slice(2))).catch((error) => {
  console.error(error.message);
  process.exit(1);
});
