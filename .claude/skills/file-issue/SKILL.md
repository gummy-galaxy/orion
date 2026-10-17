---
name: file-issue
description: Turn the person's spoken or stream-of-consciousness thoughts into an Orion intent issue labeled needs grooming. Use when the person talks through an idea, feature, or problem and asks to make it an issue, file it, write it up, or capture it.
---

# File an issue

The person thinks out loud. Turn what they said into an intent issue that keeps what they want and why, so grooming can break it down later. It doesn't have to be buildable yet, and it can carry open questions. Grooming (`.claude/skills/groom-issue/SKILL.md`) turns it into task issues.

## 1. Find the intent

Read the whole message before writing. Pull out:

- what they want to exist or change,
- why: the problem, the moment that prompted it, or what it would make possible,
- the shape they have in mind, as far as they described it,
- what they're unsure about, or said "maybe" or "or something" about.

Keep their phrasing where it carries meaning, such as a name they coined or an analogy they drew. Drop filler, false starts, and repetition.

## 2. Check what's already there

Search open issues for overlap:

```bash
gh issue list --repo vocksel/orion --state open --search '<keywords>'
```

If an open intent issue already covers it, tell the person, recommend adding to that issue, and wait for their answer. Also read [`CHARTER.md`](../../../CHARTER.md) and [`DECISIONS.md`](../../../DECISIONS.md), and note any conflict in the issue's open questions.

## 3. Write it

- **Title:** the outcome in plain language, such as "Let groups be linked like cards". Don't write a list of features.
- **Opening paragraph:** the problem or desire from the person's point of view, and why it matters.
- **What it should do:** bullets for the shape they described.
- **Open questions:** everything undecided, including gaps you noticed. Put a recommendation beside a question only when you have one.
- **Related:** issue numbers, when there are any.

Don't invent scope, decisions, or acceptance criteria the person didn't give. Write what's missing as an open question. Leave out private context: names of people who aren't on the issue, side conversations, and how the idea came up.

## 4. File it

When the person asked for the issue, file it without a separate draft review, unless they asked to see it first:

```bash
gh issue create --repo vocksel/orion --label "needs grooming" --title "<title>" --body-file <file>
```

Write the body file in your scratchpad. Reply with the link and a one-line summary of the open questions. Don't file task issues here; grooming does that.
