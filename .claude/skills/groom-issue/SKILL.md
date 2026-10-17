---
name: groom-issue
description: Groom an Orion intent issue by settling its open questions with the person and breaking it into sub-issues that one pull request each can close. Also checks which intent issues are ready to close. Use when asked to groom, triage, break down, or plan an issue or the backlog, when picking up an issue labeled needs grooming, or when an issue is too broad for one pull request.
---

# Groom an issue

An intent issue says what the person wants and why. Grooming turns it into task issues, each small enough for one pull request to close. The intent issue stays open as their hub. See the Issues section of `AGENTS.md` for the two kinds.

## Pick what to groom

When the person named an issue, groom that one. When they asked for a pass over the backlog, list what needs it:

```bash
gh issue list --repo vocksel/orion --state open --label "needs grooming"
gh api graphql -f query='{repository(owner:"vocksel",name:"orion"){issues(states:OPEN,labels:["epic"],first:100){nodes{number title subIssuesSummary{total completed}}}}}' --jq '.data.repository.issues.nodes[] | "\(.number) \(.subIssuesSummary.completed)/\(.subIssuesSummary.total) \(.title)"'
```

The second command shows each hub's progress. Hubs with most of their sub-issues closed are candidates for step 6.

## 1. Read it all

- The issue and its comments: `gh issue view <n> --repo vocksel/orion --comments`.
- Its existing sub-issues: `gh api repos/vocksel/orion/issues/<n>/sub_issues --jq '.[] | "\(.number) \(.state) \(.title)"'`.
- Merged pull requests that mention it (`gh pr list --repo vocksel/orion --state merged --search '<n>'`) and the code they touched. Don't plan work that already shipped.
- Related issues, plus [`CHARTER.md`](../../../CHARTER.md) and [`DECISIONS.md`](../../../DECISIONS.md).

## 2. Settle the questions

List the issue's open questions, along with any you found while reading. Recommend an answer for each, put the recommendation first, and ask the person in one batch. Don't answer a question yourself, even when the code points one way.

A question that needs investigation or a prototype before anyone can answer it becomes its own task issue. A lasting call goes into `DECISIONS.md` with the work that carries it out.

## 3. Draft the task issues

Each task issue:

- has one outcome and fits in one pull request,
- says what done looks like, concretely enough to check a pull request against,
- has no open questions,
- stands on its own for someone who never saw the hub's discussion,
- names the task issues it depends on, if any, as `Depends on #<n>`.

Leave out anything the intent doesn't need. A remainder of a few percent can stay unfiled, so the hub can close.

If the whole intent fits in one pull request, don't split it. Plan to rewrite the issue as a task issue instead.

## 4. Confirm the breakdown

Show the person the proposed titles in order, each with a one-line done-when, along with the hub edits from step 5. Wait for their approval before filing, since every new issue is GitHub activity.

## 5. File and update the hub

File each task as a sub-issue. Carry over the hub's priority label, and size each task:

```bash
gh issue create --repo vocksel/orion --parent <hub> --title "<title>" --body-file <file> --label "<P label>,size/<S|M|L>"
```

Then update the hub:

- Swap the label: `gh issue edit <hub> --remove-label "needs grooming" --add-label epic`.
- Edit its body in place. Keep the person's words and intent. Move answered questions into a **Decisions** section with their answers. Don't remove media or other content.

When the intent became a single task issue, rewrite the issue as one, remove `needs grooming`, and add no `epic` label.

## 6. Close finished hubs

A hub is done when its intent is met, even with a few nice-to-have sub-issues still open. When a hub you looked at looks done, say why and ask the person before closing it:

```bash
gh issue close <hub> --repo vocksel/orion --reason completed
```

Its open sub-issues stay open as task issues on their own.
