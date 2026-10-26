# Adapters

Everything Orion reads from outside comes through an adapter, one per kind of source, such as `github`, `jira`, or `hop`. An adapter answers two kinds of question. Source verbs bring work in from a service as cards and refs. Agent verbs find an agent tool's sessions and talk to them. An adapter offers either set or both, and Orion calls only the verbs an adapter has, so a new kind of source or a second agent plugs in without a change to the app.

The contract lives in `workspace/orion-cli/src/adapters/types.luau`, and `adapters/getAdapter.luau` registers each adapter by its kind. Every adapter has:

- **`kind`**, the word `orion source add <kind>` takes.
- **`createSource`**, which checks the options given to `orion source add` and returns the source to record, plus the command this machine runs for it when the kind runs a program. The command goes to this machine's `commands.json`, never to the canvas's files.

A verb that waits on a program, through the `CommandRunner` it's given, ends in `Async`.

## Source verbs

An adapter's `source` field holds these. Only `collectAsync` is required.

| Verb                  | What it does                                                                                                                                                                                       |
| --------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `collectAsync`        | Runs the source and returns records for `orion ingest` to place: a ref, a label, and how to find or file the card it belongs to.                                                                   |
| `collectOrder`        | When this kind collects relative to others, lowest first. Hop goes after GitHub, so the cards GitHub adds this pass can take hop's branches.                                                       |
| `refreshAsync`        | Keeps the refs already on the canvas current, such as pull request states. It fetches against a snapshot and returns the step that applies the results, so the fetch runs outside the canvas lock. |
| `refreshChangedAsync` | Like `refreshAsync`, limited to what changed since the last poll. `orion server start`'s background loop uses it.                                                                                  |
| `refFromUrl`          | Recognizes a pasted URL for this kind, for `--ref`.                                                                                                                                                |
| `refFromKey`          | Builds a ref from `<source>:<key>` addressed to a source of this kind, for `--ref`.                                                                                                                |
| `lookupRefsAsync`     | Looks up records for a batch of refs in as few calls as the service allows, for `orion card import`. A failure for one ref carries a reason.                                                       |

A ref keeps what the source said in its own terms in `details`, which only its adapter reads. The adapter also writes source-neutral facts beside it, such as `stateLabel`, `readiness`, and `checks`, and the app shows those as they are. A new source that fills in the same facts shows up on cards with no app change.

## Agent verbs

An adapter's `agent` field holds these. `name`, `listSessionsAsync`, and `readTurnsAsync` are required.

| Verb                | What it does                                                                                                                                                                     |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `name`              | The agent's name as people know it, such as "Claude Code", for labels like "Waiting on you in Claude Code".                                                                      |
| `listSessionsAsync` | Lists the sessions that changed since a time, read from the agent's own records without writing anything.                                                                        |
| `readTurnsAsync`    | Reads a session's last few turns, oldest first, with tool calls and their results left out. Returns nothing when the agent has no session with that id.                          |
| `resumeAsync`       | Sends a message to a session without opening it, and hands back each turn of the reply as it arrives. Nothing calls it yet, and its shape may change when headless resume lands. |
| `startAsync`        | Starts a session in a folder with a prompt, and hands back its turns as `resumeAsync` does. Nothing calls it yet either.                                                         |

Each session an adapter lists carries the same fields whatever the agent:

- **`id`**: the agent's own id for the session.
- **`cwd`** and **`branch`**: the folder it ran in and the branch checked out there, which tie it to a card. **`repo`** is the repository as `owner/name`, when the adapter knows it without asking git.
- **`state`**: `working` while the agent runs a turn, and `waiting` once it's your move. A session that finished its turn reads as waiting, the same as one stopped at a permission prompt or an interrupt.
- **`isLive`**: whether the agent's process is still running, or nothing when the adapter can't tell. Resuming a session is to warn when it's live, and whenever the adapter can't tell ([#614](https://github.com/gummy-galaxy/orion/issues/614)).
- **`title`**, **`lastMessage`**, and **`updatedAt`**: what to call it, the last thing the agent said, and when it last changed.
- **`details`**: what the agent recorded in its own terms, which only its adapter reads.

Agent verbs read the agent's records each time Orion asks, so Orion keeps refs and derived state rather than a copy of a transcript. Reading those records cheaply is the adapter's job: Claude Code's, for example, reads only the end of each transcript and asks its running processes whether they're busy.
