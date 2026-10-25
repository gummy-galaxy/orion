# Changelog entries

Each change that people will notice gets an entry in [`.changes/`](../.changes/README.md), which describes its format. Changewrite combines the entries into release notes when a release is cut. Run `changewrite check` before you push to confirm your entry is valid.

## When an entry is needed

A pull request that changes anything under `workspace/` needs an entry. CI's `changelog` job runs the check whenever a pull request touches the CLI, the app, or the desktop app, and it fails without a valid entry. That also includes pull requests that change `.lute/`, the shared CI and toolchain setup, or the root config, since those run the same jobs. Docs-only changes don't need one.

## Choosing the fields

- **`kind`** describes what a person using Orion experiences. `new` is a capability Orion didn't have. `improved` is an existing one that works better. `fixed` is a bug that's now corrected. `breaking` is a change that stops something people rely on from working, such as a command, an option, or a file format.
- **`bump`** follows from `kind`: `breaking` is `major`, `new` is `minor`, and `improved` or `fixed` is `patch`.
- **`category`** names the surface the change lands on. Pick the one where a person would notice it. A change to a card's look is Cards even if it touched the canvas code. Use Agents for anything the `orion` CLI or the MCP tools do. Use Under the hood for internal work with no visible effect, such as refactors, tests, build, and CI. Under the hood entries are `patch` and usually `improved` or `fixed`.
- **`highlight`** is optional. Add a short title only for a change that deserves a headline in the release notes, such as a new way to work. Leave it out for most entries.

If a change spans two surfaces, split it into two entries, one per surface, so each reads on its own.

## Writing the body

Write one or two plain sentences for someone using Orion who hasn't seen the code. Describe what they can now do, what no longer goes wrong, or what they need to change, in their terms.

- Start with the change itself, not with "This PR" or "We".
- Leave out file names, function names, issue numbers, and internal terms. A command or option name is fine when people type it.
- For a `fixed` entry, say what used to happen and that it doesn't now.
- For a `breaking` entry, say what stops working and what to use instead.

For example, "Cards can now be grouped by outcome, so a whole goal reads as one block on the canvas" works, and "Added outcome grouping to the canvas derive step" doesn't.
