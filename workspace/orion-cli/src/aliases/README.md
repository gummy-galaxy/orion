# Aliases

An alias keeps a renamed command or option working under its old name, as a migration in [`../migrations/`](../migrations/README.md) keeps an older data folder working. They share one lifecycle: the code here is permanent, and the entries are pruned.

- `resolveArguments.luau` rewrites an old command path or option before the CLI parses it, and the CLI prints a one-line notice to stderr for each rewrite, so `--json` output stays the same. Help doesn't list aliases.
- `../cli/mcp/catalog/buildTools.luau` gives each MCP tool the old names and argument names its aliases imply, and a `tools/call` with one of them runs the current tool. `tools/list` doesn't show them.
- `checkAliases.luau` checks every entry against the command table. `entries.spec.luau` runs it on the shipped entries, so a target that doesn't exist, an old name that hides a live command or option, or a missing date or pull request fails the tests.

A command alias also renames the commands under it, so `workspace` to `canvas` covers `workspace list`. An option alias renames a long option on one command, named by the command's current path.

**Delete every row below at each release**, along with its entry in `entries.luau`, in the same step that clears the migrations, so each release starts with none.

| From | To | Added |
| --- | --- | --- |
| `orion card add` | `orion card create` | 2026-10-21, [#566](https://github.com/vocksel/orion/pull/566) |
| `orion note add` | `orion note create` | 2026-10-21, [#566](https://github.com/vocksel/orion/pull/566) |
| `orion link add` | `orion link create` | 2026-10-21, [#566](https://github.com/vocksel/orion/pull/566) |
| `orion group add` | `orion group create` | 2026-10-21, [#566](https://github.com/vocksel/orion/pull/566) |
| `orion media insert` | `orion media add` | 2026-10-21, [#566](https://github.com/vocksel/orion/pull/566) |
| `orion backup list` | `orion history list` | 2026-10-26, [#668](https://github.com/gummy-galaxy/orion/pull/668) |
| `orion backup restore` | `orion history set` | 2026-10-26, [#668](https://github.com/gummy-galaxy/orion/pull/668) |

Add a row for each new alias, with the date and pull request that added it, and its entry in `entries.luau`. Write a command row as `` | `orion card new` | `orion card create` | 2026-10-19, [#1](…/pull/1) | ``, and an option row's names as `` `--folder` on `orion card create` ``.
