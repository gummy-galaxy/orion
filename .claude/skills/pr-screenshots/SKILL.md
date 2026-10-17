---
name: pr-screenshots
description: Capture before and after screenshots of the Orion app and attach them to a pull request description. Use when opening or updating a pull request that changes what the app shows, such as anything under app/src or the desktop shell's UI, or when asked for screenshots on a PR.
---

# PR screenshots

Every pull request that changes what the app shows gets before and after screenshots in its description. Skip pull requests whose changes can't be seen: CLI-only work, tests, tooling, docs, and refactors with no visible change.

Capture both images the same way: same data, window size, theme, and steps. Only the code should differ.

## 1. Pick what to show

Choose one to three views that show the change, such as the canvas with a group open, a menu, or a single card. Prefer a Storybook story when one covers the change, since it needs no data. Use the full app when the change depends on real layout or data.

A new feature has nothing to show before it. Attach the after image alone, or a before image of the same spot when its absence is worth seeing.

These captures show only the app's web content. Parts the desktop shell draws, such as the window buttons and macOS menus, need the desktop app: run `npm run dev` in `desktop/` and leave it open for the person to capture, or say in the description what the images leave out.

## 2. Prepare two trees and two data copies

Use the branch's worktree for after. Build before from where the branch left main:

```sh
SCRATCH=$(mktemp -d /tmp/orion-screenshots.XXXXXX)
git fetch origin
git worktree add --detach "$SCRATCH/before" "$(git merge-base origin/main HEAD)"
```

Reuse `node_modules` when `app/package-lock.json` is unchanged; otherwise run `npm ci` in the before tree's `app/`:

```sh
ln -s "$PWD/app/node_modules" "$SCRATCH/before/app/node_modules"
```

Give each app its own copy of the data. Never point either at the real data folder, since `orion server start` writes to it. Copy only the `orion` canvas, which tracks Orion's own work, or build a small sample with the CLI against the copy:

```sh
for side in before after; do
  mkdir -p "$SCRATCH/$side-data/canvases"
  cp ~/Library/Application\ Support/Orion/canvases.json "$SCRATCH/$side-data/"
  rsync -a --exclude backups ~/Library/Application\ Support/Orion/canvases/orion "$SCRATCH/$side-data/canvases/"
  ORION_DATA_DIR="$SCRATCH/$side-data" /Applications/Orion.app/Contents/MacOS/orion canvas use orion
done
```

Seed whatever the change needs, such as a gate card or a long label, with the same CLI commands in both copies.

## 3. Start one app at a time

Run Vite in each tree's `app/` on fixed ports. Use the installed `orion` binary for both unless the pull request changes the CLI or `orion server start`; then each side needs its own `cli/build/orion`.

Run one side, capture it, and stop it before starting the other. A linked `node_modules` means both trees share Vite's dependency cache in `node_modules/.vite`, and two servers at once leave one blank with "504 Outdated Optimize Dep". Pass `--force` so each start rebuilds that cache for its own tree:

```sh
ORION_BIN=/Applications/Orion.app/Contents/MacOS/orion ORION_DATA_DIR="$SCRATCH/before-data" npx vite --port 5301 --strictPort --force
ORION_BIN=/Applications/Orion.app/Contents/MacOS/orion ORION_DATA_DIR="$SCRATCH/after-data" npx vite --port 5302 --strictPort --force
```

Start each with your harness's dev-server tool when it has one, such as Claude Code's `preview_start` with entries in `.claude/launch.json`. Otherwise run it in the background.

For a story, run `ORION_STORYBOOK=1 npx storybook dev -p 6011 --ci` in the before tree's `app/`, then the same with `-p 6012` in the after tree's, one at a time, and capture `http://localhost:<port>/iframe.html?id=<story-id>&viewMode=story`.

## 4. Capture

`scripts/capture.mjs` drives headless Chrome with no npm packages. Run the same command against each side's port, changing only `--url` and `--out`:

```sh
node .claude/skills/pr-screenshots/scripts/capture.mjs \
  --url http://localhost:5302 --out "$SCRATCH/after-editing-group.png" \
  --wait-for .react-flow__node --click-text Editing --delay 1200
```

- `--click-text <text>` clicks the innermost visible element whose text starts with it. `--click`, `--right-click`, and `--middle-click` press that button at an element's center, `--hover` moves there without pressing, and `--eval <js>` runs code in the page. They repeat and run in order.
- The image shows a cursor where the last pointer step acted: a ring at the point and a small mouse just below and to its right, where an arrow cursor would sit, with the pressed button filled in. Left clicks are blue, right clicks orange, middle clicks purple, and `--hover` a thin gray ring with no button pressed. It's drawn just before the capture and removed after, and it's skipped when the element it acted on is gone by then, such as a menu item that closed its menu. Prefer real pointer steps over `--eval` for clicks so the cursor shows what happened. When an `--eval` step does the clicking, add `--pointer <x>,<y>,<idle|left|right|middle>` after it to place the cursor. Use `--cursor off` only when the cursor would hide the change.
- `--selector <css>` crops to one element, which suits menus, cards, and panels. The crop keeps 32 px of the page around the element so shadows, borders, and nearby context stay in the frame. Raise `--padding` when the surroundings help explain the change, and never set it to 0: a crop flush with the element's edges reads as cut off.
- `--theme light|dark` sets the color scheme. Defaults are 1440×900 at 2× scale.
- Raise `--delay` when the canvas is still animating or measuring groups.

Name files `before-<view>.png` and `after-<view>.png`. Open every image and check that it shows the change and that both sides match apart from it. Recapture rather than attach a misleading pair.

## 5. Attach

GitHub hosts the images. Attaching a file to any of a pull request's comment or description editors on github.com uploads it right away and turns it into a `https://github.com/user-attachments/assets/…` link, which works whether or not the text is ever posted. Never commit screenshots to the repository or any branch.

With a browser tool that can set files on an input, such as Chrome DevTools MCP's `upload_file` or Claude in Chrome's `file_upload`, get the links from the comment box and write the description with `gh`. This needs no clicks in the description editor:

1. Open the pull request in a background tab of a browser signed in to GitHub.
2. Find the "Attach files" button in the "Add a comment" form and attach every image to it in one call.
3. Wait until the comment's textarea no longer says "Uploading", then read the `src` of each `<img>` tag GitHub inserted. Use those links in the Markdown below with your own alt text.
4. Clear the textarea and dispatch an `input` event on it so GitHub drops the draft. Never submit the comment.
5. Fetch the live description with `gh pr view <n> --json body -q .body`, change only the Screenshots section, and save it with `gh pr edit <n> --body-file <file>`.

Browser tools read files only from certain folders, so copy the chosen images there first:

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

When there's no before image, keep the Before heading with `<!-- Add screenshots of the previous behavior, if applicable. -->` beneath it.

Reread the live description first and change only this section. If it already holds screenshots or media someone else added, propose the change in chat instead. When later pushes change what the images show, recapture and replace the links in the same section.

## 6. Clean up

Stop any server still running and remove the before tree with `git worktree remove "$SCRATCH/before"`. Leave the images in `/tmp` once they're attached.
