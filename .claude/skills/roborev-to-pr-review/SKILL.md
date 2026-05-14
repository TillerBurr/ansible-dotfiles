---
name: roborev-to-pr-review
description: Use when drafting a GitHub PR review for a single PR and want roborev to generate the findings instead of reading the diff manually. Triggered by /roborev-to-pr-review or by asking to "review this PR with roborev as the source / via roborev". Not for /roborev-fix (in-place fixes) or /roborev-review-branch (verdict only, no GH comments).
---

# roborev-to-pr-review

Compose `roborev review` (finding generator) with the `gh-pr-review` skill's PENDING-review pattern (comment delivery). Roborev produces structured findings; you triage which become inline GitHub comments; the gh-pr-review flow creates a PENDING review for the user to submit manually in the GitHub UI.

**Invariants inherited from gh-pr-review (do not violate):**

- Never submit programmatically. No `event` field. No `/events` endpoint.
- Always create PENDING only. User submits in the GitHub UI.
- Verify every `line` against the file at the PR's head SHA — roborev's anchor is a hint, not ground truth.
- Every comment `body` starts with `Comment by Claude :robot: (via roborev)\n\n` — extends the gh-pr-review attribution so the source is honest.

## When to use

- User asks to "review this PR via roborev" / "use roborev's findings as PR comments"
- User invokes `/roborev-to-pr-review <PR# | URL | branch>`
- Exactly one PR per invocation

## When NOT to use

- User just wants the roborev verdict for their own reading → `/roborev-review-branch`
- User wants findings *fixed* in code, not posted as comments → `/roborev-fix`
- Multi-PR batch → out of scope; run once per PR, or use `/roborev-review-prs` first and bring one job ID back here
- User has already pasted findings in chat → skip the roborev run step; jump to triage (step 4)

## Workflow

### 1. Resolve PR + branch + base + head SHA

```bash
gh pr view <arg> --json number,headRefName,baseRefName,commits,url \
  --jq '{n:.number, branch:.headRefName, base:.baseRefName, sha:.commits[-1].oid, url:.url}'
```

If `<arg>` is a branch name, find the open PR for it. Pin `sha` — it's the `commit_id` the pending review must reference.

### 2. Run roborev (foreground, wait)

Mirrors `/roborev-review-branch`:

```bash
git fetch origin <branch>
git branch -f <branch> origin/<branch>      # force-update so stale local ref doesn't mask new commits
roborev review --branch=<branch> --base <base> --wait
```

Foreground because findings are the next input. If the daemon is down: `roborev status` → `roborev init`.

Parse the output into a list of findings, each with: severity (H/M/L/nit), path, line (and `start_line` if range), body, optional ```suggestion block.

### 3. Verify line numbers against the file at HEAD SHA

For each finding:

```bash
gh api "repos/:owner/:repo/contents/<path>?ref=$SHA" --jq '.content' | base64 -d | nl -ba | sed -n '<L-2>,<L+2>p'
```

Confirm the cited line exists and is an added or context line on `RIGHT`. Roborev has anchored to the wrong line before (PR #1189 prior incident — see `feedback_pr_review_line_numbers.md`). Treat anchors as guesses until verified; reanchor or drop if the file has moved on.

### 4. Triage (stage 1: multiSelect)

`AskUserQuestion` with `multiSelect: true`. One option per finding:

- `label`: `[<severity>] <path>:<line> — <one-line summary>`
- `description`: roborev's full finding body (so the user can decide without re-reading the diff)

User checks which findings become comments. Skip this question entirely if roborev returned zero findings — go straight to step 7 and report "Pass, no comments to post".

### 5. Synthesize kept findings into comment bodies

Each kept finding → one entry in the `comments[]` JSON payload:

- `path`, `line` (+ `start_line` for ranges), `side: "RIGHT"`
- `body` starts with `Comment by Claude :robot: (via roborev)\n\n`, then roborev's text
- Preserve roborev's ```suggestion blocks verbatim — they replace the cited line(s)
- If roborev split one issue across multiple findings on adjacent lines, merge into a single comment with a range anchor

### 6. Final approval (stage 2: yes/no)

Follow gh-pr-review's pattern exactly. Show:

- Each comment's `path:line` + body (and suggestion block if present)
- Suggested event type for the user to apply in the UI (`COMMENT` / `APPROVE` / `REQUEST_CHANGES`) — informed by roborev's overall verdict and the highest severity kept:
  - Fail + any H kept → suggest `REQUEST_CHANGES`
  - Pass, or only L/nits kept → suggest `COMMENT` (or `APPROVE` if user wants)
- Suggested one-line overall message

`AskUserQuestion` yes/no to "create this PENDING review".

### 7. Create PENDING review

Write the JSON payload to `/tmp/review_<PR#>.json` and:

```bash
gh api repos/:owner/:repo/pulls/<n>/reviews \
  -X POST \
  --input /tmp/review_<PR#>.json \
  --jq '{id, state}'
```

Required result: `state: PENDING`. No `event` field in the payload. The flag-form `-f 'comments[][...]'` mis-groups fields for multi-comment payloads — always use `--input`.

### 8. Hand off to user

Print the PR URL and the standard submit instructions: open PR → Files changed → Finish your review → pick event type → submit.

## Triage UX example

```
Question: "Which roborev findings should land as comments? (multi-select)"
Header: "Triage"
Options:
  - [H] src/auth.py:42 — token expiry not validated
    description: roborev finding body, including reasoning + code suggestion
  - [M] src/util.py:88 — missing error handling around fetch
    description: ...
  - [L] src/util.py:103 — stale comment references removed module
    description: ...
```

Dropped findings produce no comment. The roborev verdict and finding count are not posted anywhere — they're internal context only.

## Cross-reference

- **REQUIRED SUB-SKILL:** `gh-pr-review` — payload shape, PENDING-only invariant, attribution prefix, line-anchor verification. Don't reimplement; this skill only adds the roborev-source layer on top.
- **REQUIRED SUB-SKILL:** `roborev-review-branch` — fetch + force-update + daemon check + `roborev review` flag semantics.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Posting roborev's verdict text as the overall review message | The overall message is what the *user* types/pastes when submitting. Suggest a one-liner; don't paste roborev's full block. |
| Skipping per-comment triage and posting every finding | Roborev produces more findings than a human reviewer would post. Always triage; this is the whole point of the skill. |
| Trusting roborev's line number without checking | Same rule as gh-pr-review. Verify each `line` against the file at HEAD SHA. |
| Submitting programmatically because the user said "go ahead" | Never. PENDING only. Direct them to the PR URL. |
| Dropping the `(via roborev)` attribution | Every comment body MUST start with `Comment by Claude :robot: (via roborev)`. The source is the whole reason for the suffix. |
| Multi-PR batch in one run | Out of scope. One PR per invocation. |
| Re-running roborev when user pasted findings | If the user has already pasted findings in the chat, skip step 2. Jump to triage with the pasted list. |

## Quick reference

```bash
# 1. Resolve
gh pr view <arg> --json number,headRefName,baseRefName,commits,url

# 2. Roborev
git fetch origin <branch> && git branch -f <branch> origin/<branch>
roborev review --branch=<branch> --base <base> --wait

# 3. Verify a finding's line
gh api "repos/:owner/:repo/contents/<path>?ref=$SHA" --jq '.content' | base64 -d | nl -ba | sed -n '<L-2>,<L+2>p'

# 7. Create pending (after both approvals)
gh api repos/:owner/:repo/pulls/<n>/reviews -X POST --input /tmp/review_<n>.json --jq '{id, state}'
```
