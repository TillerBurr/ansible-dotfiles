---
name: github-pr-review
description: Use when drafting GitHub pull request reviews with gh CLI - creates PENDING reviews with code suggestions batched; user submits manually in GitHub UI
allowed-tools: AskUserQuestion
---

# GitHub PR Review

## Overview

Workflow for drafting GitHub PR reviews using `gh api`. Creates **pending reviews only**. Submission is performed manually by the user in the GitHub UI.

**CRITICAL: Never submit reviews programmatically. Never call the `/events` endpoint. Never pass an `event` field on review creation.**

**CRITICAL: Always get explicit user approval before creating the pending review.** Show exactly what will be drafted and ask for yes/no confirmation using AskUserQuestion.

## When to Use

- Drafting pull request reviews
- Adding code suggestions to PRs as pending comments
- Preparing review comments for user to submit via GitHub UI

## Prerequisites

**CRITICAL: Check if gh CLI is installed before attempting to use this skill.**

### Check for gh CLI

```bash
gh --version
```

**If gh is not installed:**

1. Stop immediately
2. Inform user:

```
The GitHub CLI (gh) is required for this skill but is not installed.

Please install it from: https://cli.github.com/

Installation options:
- macOS: brew install gh
- Windows: winget install GitHub.cli
- Linux: See https://cli.github.com/ for your distro

After installing, authenticate with:
  gh auth login

Then try your PR review request again.
```

3. Do not proceed until gh is installed

### After Installation

```bash
gh auth login
```

## Core Workflow

**REQUIRED STEPS (do not skip):**

1. **Check gh CLI is installed** - Run `gh --version`
2. **Draft the review** - Analyze PR and prepare all comments
3. **Verify every line number from the actual file** - See "Anchoring line numbers" below. Do NOT estimate from `gh pr diff` hunk headers
4. **Show user exactly what will be drafted** - Use AskUserQuestion with yes/no
5. **Get explicit approval** - Wait for user confirmation
6. **Create PENDING review only** - Do not submit
7. **Tell user to submit via GitHub UI** - Provide PR URL

### Anchoring line numbers

**Comments anchored from diff hunk headers land on the wrong lines.** The unified diff numbers context lines and added lines together, and it's easy to miscount across multiple hunks. Always confirm the target line against the actual file at the PR's head SHA before building the JSON payload.

Pick one:

```bash
# Option A — check out the PR locally and Read the file
gh pr checkout <PR_NUMBER>
# then use the Read tool on the target file and pick the line visually

# Option B — fetch the file at the PR head SHA without checking out
SHA=$(gh pr view <PR_NUMBER> --json commits --jq '.commits[-1].oid')
gh api "repos/:owner/:repo/contents/<path>?ref=$SHA" --jq '.content' | base64 -d | nl -ba | sed -n '<start>,<end>p'
```

Rules:
- Treat any line number derived purely from `gh pr diff` as a guess that needs verification.
- For multi-line anchors, pass both `start_line` and `line` so the range is unambiguous.
- The `line` value must be an added or context line in the diff (not a removed line) when `side: RIGHT`.

### Approval Pattern

Before creating ANY pending review, use AskUserQuestion to show:
- File and line number for each comment
- Exact comment text (including code suggestions)
- Suggested event type for user reference (APPROVE/REQUEST_CHANGES/COMMENT) — user applies this in UI
- Overall review message (user will paste or type in UI when submitting)

**Example:**
```
Question: "Ready to draft this pending review?"
Header: "PR Review Draft"
Options:
  - Yes, create pending: Creates PENDING review for manual submission
  - No, let me revise: Allows refinement
```

### Technical Workflow

**Create PENDING review only. Do NOT submit.**

**Attribution prefix (REQUIRED):** every `body` must start with `Comment by Claude :robot:` on its own line, followed by a blank line, then the actual comment. Example body: `"Comment by Claude :robot:\n\nActual comment text..."`. Applies to every comment in every review.

**Multi-comment reviews: use `--input <json_file>`.** The repeated `-f 'comments[][path]=...'` flag form silently mis-groups fields across comments and fails with HTTP 422 ("`side` not defined on DraftPullRequestReviewComment", "`position` expected not null", stray `body` nulls). Always build a JSON payload and pipe it in.

```bash
# Write the review payload to a temp file
cat > /tmp/review.json <<'EOF'
{
  "commit_id": "<COMMIT_SHA>",
  "comments": [
    {
      "path": "path/to/file.ts",
      "line": 20,
      "side": "RIGHT",
      "body": "Comment by Claude :robot:\n\nComment text\n\n```suggestion\n// suggested code\n```"
    },
    {
      "path": "path/to/other.ts",
      "line": 35,
      "side": "RIGHT",
      "body": "Comment by Claude :robot:\n\nSecond comment..."
    }
  ]
}
EOF

# Create PENDING review (no `event` field — omitting keeps it pending)
gh api repos/:owner/:repo/pulls/<PR_NUMBER>/reviews \
  -X POST \
  --input /tmp/review.json \
  --jq '{id, state}'

# Returns: {"id": <REVIEW_ID>, "state": "PENDING"}
```

**Single-comment reviews** may use the flag form, but the `--input` JSON pattern works for any count and is safer as a default:

```bash
gh api repos/:owner/:repo/pulls/<PR_NUMBER>/reviews \
  -X POST \
  -f commit_id="<COMMIT_SHA>" \
  -f 'comments[][path]=path/to/file.ts' \
  -F 'comments[][line]=20' \
  -f 'comments[][side]=RIGHT' \
  -f $'comments[][body]=Comment by Claude :robot:\n\nSingle comment body' \
  --jq '{id, state}'
```

**DO NOT run any submit step.** After creating the pending review, print the PR URL and instruct the user to open it in the GitHub UI, review the pending comments, select the appropriate event type (Comment / Approve / Request changes), add any overall message, and click "Submit review".

```bash
# Provide user the URL to submit manually
gh pr view <PR_NUMBER> --json url --jq '.url'
```

Then tell the user:
> Pending review created. Open the PR in GitHub, review your pending comments, choose Comment / Approve / Request changes, and submit manually.

## Event Types (User Reference Only)

Suggest the appropriate event type for the **user** to select in the GitHub UI:

| Event Type | When to Suggest | Example Situations |
|------------|-----------------|-------------------|
| `APPROVE` | Non-blocking suggestions, PR is ready to merge | Minor style improvements, optional refactoring |
| `REQUEST_CHANGES` | Blocking issues that must be fixed | Security vulnerabilities, bugs, failing tests |
| `COMMENT` | Neutral feedback, questions | Asking for clarification, neutral observations |

**You never apply these yourself.** User selects in UI.

## Quick Reference

### Getting Prerequisites

```bash
# Get commit SHA
gh pr view <PR_NUMBER> --json commits --jq '.commits[-1].oid'

# Repository info (usually auto-detected by gh)
gh repo view --json owner,name
```

### Required Parameters

- `commit_id`: Latest commit SHA from the PR
- `comments[][path]`: File path relative to repo root
- `comments[][line]`: End line number (use `-F` for numbers)
- `comments[][side]`: Use `RIGHT` for added/modified lines (most common), `LEFT` for deleted lines
- `comments[][body]`: Must start with `Comment by Claude :robot:` + blank line, then comment text with optional ```suggestion block

### Optional Parameters

- `comments[][start_line]`: For multi-line code suggestions (use `-F`)
- `event`: **NEVER SET.** Omitting keeps the review PENDING for manual submission.

### Syntax Rules

✅ **DO:**
- Use single quotes around parameters with `[]`: `'comments[][path]'`
- Use `-f` for string values
- Use `-F` for numeric values (line numbers)
- Use triple backticks with `suggestion` identifier for code suggestions
- Leave the review PENDING

❌ **DON'T:**
- Pass an `event` field
- Call `/reviews/<REVIEW_ID>/events`
- Submit the review on the user's behalf under any circumstance
- Use double quotes around `comments[][]` parameters
- Mix up `-f` and `-F` flags

## Code Suggestions Format

```bash
-f $'comments[][body]=Comment by Claude :robot:\n\nYour comment explaining the issue

```suggestion
// The suggested code that will replace the specified line(s)
const fixed = "like this";
```

Additional context or explanation after the suggestion.'
```

**Important**: Code suggestions replace the entire line or line range. Make sure the suggested code is complete and correct.

### Edge Case: Suggestions with Nested Code Blocks

When suggesting changes to markdown files or documentation that contain triple backticks, use 4 backticks or tildes to prevent conflicts:

`````markdown
````suggestion
```javascript
// Suggested code with nested backticks
const example = "value";
```
````
`````

Or use tildes:

```markdown
~~~suggestion
```javascript
const example = "value";
```
~~~
```

## Common Mistakes

| Mistake | Fix |
|---------|-----|
| Submitting the review programmatically | Never submit. Leave PENDING. User submits in UI. |
| Estimating `comments[].line` from `gh pr diff` hunk headers | Read the file at the PR head SHA (`gh pr checkout` + Read, or `gh api .../contents?ref=$SHA`) and pick the line visually. |
| Passing `event` field on review creation | Omit `event` entirely |
| Calling `/reviews/<id>/events` endpoint | Do not call. Ever. |
| "User asked me to submit it" | Still do not submit. Point them to the PR URL. |
| Forgetting single quotes around `comments[][]` | Always quote: `'comments[][path]'` |
| Using `-f 'comments[][...]'` for multi-comment reviews | Flag form mis-groups fields → HTTP 422. Use `--input <json_file>` instead. |
| Not getting commit SHA | Run `gh pr view <NUMBER> --json commits --jq '.commits[-1].oid'` |

## Red Flags - You're About to Violate the Pattern

Stop if you're thinking:
- "User said ASAP so I'll submit directly"
- "I'll just submit it to save a step"
- "User already approved so I'll submit too"
- "One click in UI is annoying, I'll automate it"
- "I'll post it and then tell them what I posted"
- "I'll check for gh later, let me draft the review first"

**All of these mean: STOP. Check gh. Get approval. Create PENDING only. User submits in UI.**

**Why pending-only?** Submission is an explicit, public, permanent action. The user retains sole authority to:
- Choose the event type (APPROVE / REQUEST_CHANGES / COMMENT)
- Edit the overall review message in context
- Review pending comments one last time before the PR author is notified
- Abort without any public trace

## Complete Example

**Step 1: Draft and show for approval**

```
I've reviewed PR #123 and found 3 issues. Here's what I'll draft as a PENDING review:

**Comment 1:** src/auth.ts line 20
Token expiry validation is missing...
[code suggestion shown]

**Comment 2:** src/auth.ts line 35
Missing error handling...
[code suggestion shown]

**Comment 3:** tests/auth.test.ts line 12
Missing error case test...
[code suggestion shown]

**Suggested event type (for you to select in UI):** REQUEST_CHANGES
**Suggested overall message:** "Found 3 issues that need to be addressed before merging."

Ready to create this PENDING review?
```

**Step 2: After approval, create PENDING review only**

```bash
# Build JSON payload — required for multi-comment reviews (flag form mis-groups fields → 422)
cat > /tmp/review.json <<'EOF'
{
  "commit_id": "abc123",
  "comments": [
    {"path": "src/auth.ts",       "line": 20, "side": "RIGHT", "body": "Comment by Claude :robot:\n\nFirst issue..."},
    {"path": "src/auth.ts",       "line": 35, "side": "RIGHT", "body": "Comment by Claude :robot:\n\nSecond issue..."},
    {"path": "tests/auth.test.ts", "line": 12, "side": "RIGHT", "body": "Comment by Claude :robot:\n\nThird issue..."}
  ]
}
EOF

# Create pending review — NO event field
gh api repos/:owner/:repo/pulls/123/reviews \
  -X POST \
  --input /tmp/review.json \
  --jq '{id, state}'

# Output: {"id": 987654, "state": "PENDING"}
```

**Step 3: Direct user to submit manually**

```
Pending review created (state: PENDING).

Open the PR: https://github.com/<owner>/<repo>/pull/123

In the Files changed tab, click "Finish your review", select:
  - Comment / Approve / Request changes (suggested: REQUEST_CHANGES)
  - Add overall message (suggested: "Found 3 issues that need to be addressed before merging.")
  - Click "Submit review"
```

## Real-World Impact

**Pending-only pattern:**
- User retains full control of the submit action
- Event type chosen by user in full PR context
- No accidental public comments
- Aborts leave no trace
- All feedback batched in one coherent draft
