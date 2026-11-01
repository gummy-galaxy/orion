# Issues

- **Before building.** When the person talks through a new idea, or wants to start building something no issue covers yet, file the issue first and stop there. Filing it puts the idea next to the open issues, so it can be weighed against work that may matter more. Before building an issue that's still labeled `needs grooming`, name its open questions and suggest settling them first. Both are strong defaults, not gates: when the person says to skip them, build without asking again.
- **Follow-ups.** Work that turns up mid-task and doesn't belong in the current pull request becomes an issue, not a new session, branch, or pull request. Tell the person what you filed, and start it only when they ask.
- **Filing.** When the person talks an idea through and asks for an issue, distill it into an issue labeled `needs grooming`. Follow `.claude/skills/file-issue/SKILL.md`. That issue can still carry open questions; settle them with the person, then remove the label, before building it.
- **Writing.** Give an issue one outcome, and say what done looks like concretely enough that someone who reads only the issue can tell whether a pull request finishes it. Write for someone who hasn't seen the conversation that led to it.
- **Progress.** When more than one pull request works on an issue, keep a **Progress** checklist at the end of its body. Check off each item with the pull request that shipped it, and add an unchecked item for any concrete work that turns up.

Direction and long-range plans belong in [the charter](../docs/development/charter.md).
