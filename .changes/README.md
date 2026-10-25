# Change entries

This folder holds the changes waiting for the next release. Each file describes one change: how big a version bump it needs, which surface it belongs to, and what to say about it in the release notes. [Changewrite](https://github.com/flipbook-labs/changewrite) combines the entries into the release notes and the changelog when a release is cut, then deletes the entries it used.

A pull request that changes `workspace/` adds one entry. Run `changewrite check` before you push to confirm the entry is valid. For how to write one, see [the changelog guide](../agents/changelog.md).

## Adding an entry

Create a Markdown file in this folder, named after the change, such as `add-group-outcomes.md`. The name only helps people browse the folder:

```markdown
---
bump: minor
category: Canvas
kind: new
highlight: Group cards by outcome
---

Cards can now be grouped by outcome, so a whole goal reads as one block on the canvas.
```

- **`bump`** (required) is the version step the change needs: `major`, `minor`, or `patch`. Use `major` for breaking changes, `minor` for something new, and `patch` for improvements, fixes, and internal changes. The next version is the largest bump across all pending entries.
- **`category`** (required) is the surface the change belongs to, and it must be one of these:
  - **Canvas**: laying out and linking work on the canvas, including groups, dependencies, and moving around.
  - **Cards**: what a card shows and how it looks, including its art, rarity, and status marks.
  - **Agents**: the `orion` CLI and the MCP tools that agents use. Use it for any change that someone running a command or an agent will notice.
  - **Sources**: bringing work in from outside services, such as GitHub, and keeping it current.
  - **Desktop app**: the installed app and its window, menus, and install.
  - **Under the hood**: internal changes that someone using Orion wouldn't see, such as refactors, tests, build, and CI.
- **`kind`** (required) says what kind of change it is: `new` for a capability Orion didn't have, `improved` for an existing one that works better, `fixed` for a bug that's now corrected, and `breaking` for a change that stops something people rely on from working. Under the hood entries are usually `improved` or `fixed`.
- **`highlight`** (optional) is a short title for a change worth a headline in the release notes. Leave it out for most changes.

Changewrite today reads only `bump` and `category` and ignores the other keys. `kind` and `highlight` are recorded now and shown in the release notes once [Render rich release notes in Orion](https://github.com/vocksel/orion/issues/635) lands.

**Body:** everything below the frontmatter is the release note text. Write one or two plain sentences for someone using Orion, not someone reading the code.

## Notes

- `README.md` (this file) is ignored, so it's safe to keep here.
- Entries are deleted once they're released, so they live here only while their change is unreleased.
- Changewrite checks every entry in the folder, so a bad category fails the `changelog` check on every pull request until it's fixed.
