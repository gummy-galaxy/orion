---
name: pr-screenshots
description: Capture before and after screenshots or videos of the Orion app and attach them to a pull request description. Use when opening or updating a pull request that changes what the app shows, such as anything under app/src or the desktop shell's UI, or when asked for screenshots or videos on a PR.
---

# PR screenshots

Every pull request that changes what the app shows gets before and after screenshots in its description. Skip pull requests whose changes can't be seen: CLI-only work, tests, tooling, docs, and refactors with no visible change.

Capture both sides the same way: same data, window size, theme, and steps. Only the code should differ.

## 1. Pick what to show

Choose one to three views that show the change, such as the canvas with a group open, a menu, or a single card. Prefer a Storybook story when one covers the change, since it needs no data. Use the full app when the change depends on real layout or data.

Record a video instead when a still can't show the change: an interaction such as a drag or a hover, an animation, or a state that takes several steps to reach. One video beats a run of screenshots. Keep each to the steps that show the change, usually under 15 seconds.

A new feature has nothing to show before it. Attach the after image alone, or a before image of the same spot when its absence is worth seeing.

These captures show only the app's web content. Parts the desktop shell draws, such as the window buttons and macOS menus, need the desktop app: run `npm run dev` in `desktop/` and leave it open for the person to capture, or say in the description what the images leave out.

## 2. Prepare two trees and two data copies

Keep data, images, and videos in a scratch folder, such as your session's scratchpad or `mktemp -d /tmp/orion-screenshots.XXXXXX`:

```sh
SCRATCH=<scratch folder>
```

Put the two trees beside the repository instead, under your home directory, since Lute only bundles the CLI from a checkout there. After is the pull request's head: use your own worktree when you're working on its branch, and otherwise add a detached one, leaving anyone else's worktree on that branch alone. Before is where the branch left main:

```sh
git fetch origin
BEFORE="$(git rev-parse --show-toplevel)/../orion-shots-<n>-before"
AFTER="$(git rev-parse --show-toplevel)/../orion-shots-<n>-after"
git worktree add --detach "$BEFORE" "$(git merge-base origin/main origin/<branch>)"
git worktree add --detach "$AFTER" "origin/<branch>"
```

In each tree, install the app's packages and build the CLI, which takes seconds:

```sh
for tree in "$BEFORE" "$AFTER"; do
  (cd "$tree/app" && npm ci) && (cd "$tree/cli" && lute pkg install && lute run build)
done
```

Each side runs its own CLI because the app and the server change together. An app paired with an older server can lose edits without showing an error, such as a paste that disappears. Don't link another checkout's `node_modules` either: it may lack packages the branch added, and Vite would write its cache into that checkout.

Give each app its own copy of the data. Never point either at the real data folder, since `orion server start` writes to it.

Prefer a small sample built with the CLI, which suits videos and any change that doesn't depend on real data. It loads fast and keeps real work out of a public pull request. Build it once with the before tree's CLI, since newer builds read older data. Run `"$BEFORE/cli/build/orion" --help` for its commands, such as `card add`, `link add`, and `group add`, and run each with `ORION_DATA_DIR="$SCRATCH/seed-data"`. `canvas check` reports groups waiting for layout on a fresh sample and exits nonzero, which is expected: the app settles them when it opens. Then copy the sample to each side:

```sh
for side in before after; do
  rsync -a --delete "$SCRATCH/seed-data/" "$SCRATCH/$side-data/"
done
```

Recording changes the data: a paste adds cards and a drag moves them. Run that copy again before every take, including retakes, so each starts from the same state. Stop that side's server first and start it again after: the copy deletes the `serve.json` the server keeps in its data folder, and without it the CLI can't find the server. A command such as `orion reveal` then tries to launch the installed app instead.

When a seed needs the app's own layout, such as a tidy top level, open it once in the app, run the layout there with a capture step such as Tidy canvas from the empty-canvas menu, stop the server, and copy the result back into `$SCRATCH/seed-data` without `serve.json`, `focus.json`, or `backups`.

When the change depends on real layout or data, copy only the `orion` canvas, which tracks Orion's own work, instead. These commands only read the real data folder:

```sh
for side in before after; do
  mkdir -p "$SCRATCH/$side-data/canvases"
  cp ~/Library/Application\ Support/Orion/canvases.json "$SCRATCH/$side-data/"
  rsync -a --exclude backups ~/Library/Application\ Support/Orion/canvases/orion "$SCRATCH/$side-data/canvases/"
  ORION_DATA_DIR="$SCRATCH/$side-data" "$BEFORE/cli/build/orion" canvas use orion
done
```

Seed whatever the change needs, such as a gate card or a long label, with the same CLI commands in both copies.

## 3. Start the apps

Run Vite in each tree's `app/` on its own port, each with its own tree's CLI and data:

```sh
cd "$BEFORE/app" && ORION_BIN="$BEFORE/cli/build/orion" ORION_DATA_DIR="$SCRATCH/before-data" npx vite --port 5301 --strictPort
cd "$AFTER/app" && ORION_BIN="$AFTER/cli/build/orion" ORION_DATA_DIR="$SCRATCH/after-data" npx vite --port 5302 --strictPort
```

Run them in the background, and keep everything headless so nothing opens on the person's screen. Don't use a dev-server tool that opens a browser pane, such as Claude Code's `preview_start`.

For a story, run `ORION_STORYBOOK=1 npx storybook dev -p 6011 --ci` in the before tree's `app/` and the same with `-p 6012` in the after tree's, and capture `http://localhost:<port>/iframe.html?id=<story-id>&viewMode=story`.

## 4. Capture

`scripts/capture.mjs` drives headless Chrome with no npm packages. Run the same command against each side's port, changing only `--url` and `--out`:

```sh
node .claude/skills/pr-screenshots/scripts/capture.mjs \
  --url http://localhost:5302 --out "$SCRATCH/after-editing-group.png" \
  --wait-for .react-flow__node --click-text Editing --delay 1200
```

- `--click-text <text>` clicks the innermost visible element whose text starts with it. `--click`, `--right-click`, and `--middle-click` press that button on a target, `--double-click` clicks twice, `--hover` moves there without pressing, `--drag` presses the left button on a target and `--drop` carries it to another and lets go, `--key <keys>` presses a key or shortcut such as `Meta+C`, `Shift+Tab`, `Escape`, or `Delete`, `--type <text>` types into whatever has focus, `--pause <ms>` waits, and `--eval <js>` runs code in the page and prints what it returns, which helps check state between steps. They repeat and run in order. A target is a CSS selector, acted on at the element's center, or an `<x>,<y>` point such as empty canvas.
- The pointer glides to each target, sending moves along the way, so hovers and drags behave as they do by hand.
- `--caption <text>` shows a line of text at the top of the frame until the next caption, and an empty one clears it. Use it for what the page can't show, such as a CLI command that drives the app. Run the command in the background with a delay timed to the caption, such as `(sleep 5; orion reveal <id>) & node capture.mjs … --pause 1500 --caption '$ orion reveal <id>' --pause 4000`, and check the contact sheet that the change follows the caption.
- Pointer and keyboard steps send real input, so the app handles them as it would a person's. Prefer them over `--eval` for anything a person would do. Keys go to whatever has focus, so click the canvas or a field first. Use Mac shortcuts with `Meta`: the browser runs headless on a Mac, and `Meta+A`, `C`, `X`, `V`, and `Z` also edit text fields and the clipboard.
- The image shows a cursor where the last pointer step acted: a ring at the point and a small mouse just below and to its right, where an arrow cursor would sit, with the pressed button filled in. Left clicks are blue, right clicks orange, middle clicks purple, and `--hover` a thin gray ring with no button pressed. It's drawn just before the capture and removed after, and it's skipped when the element it acted on is gone by then, such as a menu item that closed its menu. Prefer real pointer steps over `--eval` for clicks so the cursor shows what happened. When an `--eval` step does the clicking, add `--pointer <x>,<y>,<idle|left|right|middle>` after it to place the cursor. Use `--cursor off` only when the cursor would hide the change.
- Page errors, console errors, and failed requests print to stderr during a take. Read them: one usually means a step didn't do what the image or video seems to show.
- `--selector <css>` crops to one element, which suits menus, cards, and panels. The crop keeps 32 px of the page around the element so shadows, borders, and nearby context stay in the frame. Raise `--padding` when the surroundings help explain the change, and never set it to 0: a crop flush with the element's edges reads as cut off.
- `--theme light|dark` sets the color scheme. Defaults are 1440×900 at 2× scale.
- Raise `--delay` when the canvas is still animating or measuring groups.

Getting around the canvas:

- Cards inside a group aren't on the page until the group is open, so `--wait-for` and `data-id` selectors for them time out at the top level. Open the group first, such as by its entry in the sidebar, then `--pause` while it lays out.
- `--click-text` takes the first match in page order, which is often the sidebar. Use a selector when the canvas shows the same text.
- Clicking a card or group opens the details panel over the right side of the canvas. Selecting with a `--drag` and `--drop` across empty canvas avoids it. `--key Escape` closes it but also clears the selection, so don't use it before a step that needs the selection, such as a copy.
- Frame the change before recording. Capture a screenshot of the end state with the same steps and check that the change sits in open canvas, clear of the sidebar and the details panel. Move the pointer somewhere open before a paste, since pasted work lands there.

Name files `before-<view>.png` and `after-<view>.png`. Open every image and check that it shows the change and that both sides match apart from it. Recapture rather than attach a misleading pair.

### Videos

Give `--out` a name ending in `.mp4` to record a video with the same steps. This needs ffmpeg with libx264, such as Homebrew's. Recording runs headless like screenshots: it starts once `--wait-for` matches, follows the steps, and stops `--delay` milliseconds after the last one.

```sh
node .claude/skills/pr-screenshots/scripts/capture.mjs \
  --url http://localhost:5302 --out "$SCRATCH/after-drag-out.mp4" \
  --wait-for .react-flow__node --pause 800 --click-text Recorder --pause 1000 \
  --drag '.react-flow__node[data-id="encode"]' --drop 900,650
```

- The cursor stays on screen throughout and shows each press as it happens, in the colors above. Each `--key` press shows in a badge at the bottom of the frame, such as `⌘ C`, so shortcuts read as clearly as clicks.
- Videos default to 1× scale, which keeps text readable at a fraction of the size, a 1500 ms `--delay`, and a 600 ms `--glide` between targets. Pass `--scale 2` when small text matters.
- Start with a `--pause` so the opening state reads before anything moves.
- `--selector` crops to where the element ends up.

When the change adds something to click, such as a new menu item, the before side has nothing there. Give its take the same steps up to that point, then a `--pause` as long as the after side's click and what follows, so both play in step.

Then put both sides in one video, labeled and playing together, which is easier to review than two:

```sh
node .claude/skills/pr-screenshots/scripts/compare.mjs \
  --before "$SCRATCH/before-drag-out.mp4" --after "$SCRATCH/after-drag-out.mp4" \
  --out "$SCRATCH/compare-drag-out.mp4"
```

It stacks after below before, which fits the description's narrow column. `--layout side` puts them next to each other, and `--labels <before>,<after>` renames the label bars or `off` drops them.

You can't watch a video, so check each one as a contact sheet of 16 frames spread over its whole length before attaching it:

```sh
VIDEO="$SCRATCH/compare-drag-out.mp4"
DURATION=$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$VIDEO")
ffmpeg -v error -y -i "$VIDEO" -vf "fps=16/$DURATION,scale=480:-1,tile=4x4" -frames:v 1 "$SCRATCH/contact.png"
```

Text is too small to read in the sheet. To read a moment, pull a full-size frame at that time with `ffmpeg -v error -y -ss <seconds> -i "$VIDEO" -frames:v 1 "$SCRATCH/frame.png"`.

Open the sheet and check that each step happened, the cursor and key badges show it, and the change itself is visible. A step that silently did nothing, such as a shortcut sent before anything had focus, shows up here as a missing result. Fix the steps and record again rather than attach a video that doesn't show the change.

## 5. Attach

GitHub hosts the images. Attaching a file to any of a pull request's comment or description editors on github.com uploads it right away and turns it into a `https://github.com/user-attachments/assets/…` link, which works whether or not the text is ever posted. Never commit screenshots to the repository or any branch.

With a browser tool that can set files on an input, such as Chrome DevTools MCP's `upload_file` or Claude in Chrome's `file_upload`, get the links from the comment box and write the description with `gh`. This needs no clicks in the description editor:

1. Open the pull request in a background tab of a browser signed in to GitHub.
2. Find the "Attach files" button in the "Add a comment" form and attach every file to it in one call.
3. Wait until the comment's textarea no longer says "Uploading", then read the `src` of each `<img>` tag GitHub inserted, and for videos each bare `https://github.com/user-attachments/assets/…` line. Use those links in the Markdown below with your own alt text.
4. Clear the textarea and dispatch an `input` event on it so GitHub drops the draft. Never submit the comment.
5. Fetch the live description with `gh pr view <n> --json body -q .body`, change only the Screenshots section, and save it with `gh pr edit <n> --body-file <file>`.

GitHub plays `.mp4` files inline when their link sits alone on a line. Keep each video under 10 MB, the limit on free plans.

Browser tools read files only from certain folders, so copy the chosen files there first:

- Chrome DevTools MCP accepts paths under the OS temp folder, which on macOS is `$TMPDIR` (`/var/folders/…/T/`), not `/tmp`. It rejects `/tmp` because that resolves to `/private/tmp`, and it can reject the repository too. Copy the images into `"$TMPDIR/orion-screenshots/"` and upload them from there.
- Claude in Chrome's `file_upload` can't read `/tmp` either. Copy the images into your session's scratchpad and upload them from there.

Without such a tool, give the person the image paths and the section below with empty links so they can drop the images in.

Add a Screenshots section to the pull request description above Testing. Put before and after images under their own headings, each image on its own line in the same view order, with alt text that says what it shows:

```md
## Screenshots

### Before

![Before: the Editing group with cards overlapping](…)

### After

![After: the Editing group in tidy rows](…)
```

For a comparison video, put its link alone on a line under the Screenshots heading, with no Before and After headings, since its labels say which is which. A video of one side goes under that side's heading, its link alone on a line.

When there's no before image, keep the Before heading with `<!-- Add screenshots of the previous behavior, if applicable. -->` beneath it.

Reread the live description first and change only this section. If it already holds screenshots or media someone else added, propose the change in chat instead. When later pushes change what the images show, recapture and replace the links in the same section.

## 6. Clean up

Stop both Vite servers and the `orion server start` each one launched, which can outlive it: `pkill -f "$BEFORE/cli/build/orion server start"`, and the same for `$AFTER`. Remove the trees you added with `git worktree remove`, never a worktree you didn't create. Leave the images and videos in the scratch folder once they're attached.
