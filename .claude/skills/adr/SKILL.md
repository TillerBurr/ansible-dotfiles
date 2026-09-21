---
name: adr
description: Use when capturing, revising, or finalizing an Architecture Decision Record (ADR) for a non-trivial task — the key decisions behind a plan and how they held up during implementation. Triggers on "seed an ADR", "log a decision", "record why we chose", "the plan changed", "finalize the ADR", or the seed/finalize hook reminders. Modes: seed (plan time) · revise (mid-implementation) · finalize (at PR).
---

# ADR — decision record for a task

Capture the **non-obvious** decisions behind a plan and how they held up. The value is the reasoning that exists nowhere in the code: the alternative rejected and why, the constraint that forced the choice, and the mid-implementation change that proved the plan wrong.

**Bar for writing one:** only when a decision was contested or non-obvious. If the decision had one obvious answer, do NOT write an ADR — it would just restate the plan, which is noise. Say so and stop.

**Where they live:** ADRs are markdown files committed to the **current repo** under `docs/architectural_decisions/`, one per decision named `<TICKET>-<slug>.md`, with `docs/architectural_decisions/README.md` as a one-line-per-ADR index. Each file follows a fixed template — Context, Decision (immutable once seeded), Alternatives rejected, Constraints, Consequences, Revisions (append-only), Outcome. The template ships with this skill at `TEMPLATE.md` (next to this file) — never assume it lives in the repo. At finalize, an ADR for a **reused feature** can graduate into a `docs/` doc — a flat file, or a `docs/<feature>/` folder when decisions accumulate (see *Promoting a reused feature to docs*); a one-off decision stays an ADR.

Derive `<TICKET>` from the branch name: `git branch --show-current` → the JIRA key (e.g. `feat/nm-5128` → `NM-5128`). If the branch has no key, stop and ask; never invent one.

Pick the mode from the request. Default to **seed** for a new decision.

## Mode: seed (plan time)

Run after a plan is settled (native plan mode approved, or `superpowers:writing-plans` finished). Source the content from the brainstorm + plan — do not re-derive.

1. Confirm the decision clears the bar (contested / non-obvious). If not, stop and tell the user no ADR is needed.
2. `TICKET=$(git branch --show-current | grep -oiE '[a-z]+-[0-9]+' | head -1 | tr a-z A-Z)`. Empty → ask.
3. Choose `<slug>` (kebab-case, 2-4 words). Output path: `docs/architectural_decisions/<TICKET>-<slug>.md`.
4. Copy `TEMPLATE.md` (beside this skill) to that path. Fill frontmatter (`ticket`, `title`) and: **Context**, **Decision**, **Alternatives rejected**, **Constraints**, **Consequences**. Leave **Revisions** (`_None yet._`) and **Outcome** (`_TBD_`) untouched.
5. Add or update `docs/architectural_decisions/README.md`: a one-line index entry `- [NM-XXXX — title](NM-XXXX-slug.md) — status`. Create the README with a short header if absent.
6. Report the path in one line. Do not commit unless asked.

## Mode: revise (mid-implementation)

The cheap path — this must stay one small action so it actually gets done. Use whenever a planned decision changes during implementation, while the reason is fresh.

1. Find the branch's ADR under `docs/architectural_decisions/`.
2. Append ONE entry to the **Revisions** section (replace `_None yet._` on the first): `- <what changed>. Trigger: <what made the planned decision wrong>.`
3. Do NOT edit the Decision section. It stays as the original record.
4. One-line confirmation.

## Mode: finalize (at PR / completion)

Fill the Outcome and run the divergence backstop.

1. Find the branch's ADR. If none, say so and stop (nothing to finalize).
2. Compare the shipped result against the original **Decision**.
3. **Backstop:** if the shipped result diverges from the Decision but **Revisions** is still `_None yet._`, stop and ask the user for the reason(s) the plan changed, then write them as Revision entries first. A silent divergence with no logged reason is the exact failure this record exists to prevent.
4. Replace the `_TBD_` Outcome with: net diff from the original Decision, surprises, final state as shipped.
5. Decide: is this a **reused feature** (earns standing documentation) or a **one-off task decision**? One-off → skip to 7. Reused → promote it (below).
6. Update the README status if it changed (e.g. `superseded by NM-YYYY`).
7. One-line confirmation.

## Promoting a reused feature to docs

Only from finalize, only when the decision produced a feature that will be read and maintained. A one-off decision stays an ADR — do NOT promote it.

**Pick the shape by size.** Default to the single file. Use the subfolder only when the feature already has, or clearly will have, multiple decisions or multiple docs — do not create a folder for one small doc.

The immutable decision content moved from the ADR is the same in both shapes — Context, Decision, Alternatives rejected, Constraints, Consequences, Revisions (append-only), Outcome — always carrying the `<!-- IMMUTABLE -->` and `<!-- APPEND-ONLY -->` markers and a divider comment above it: `<!-- Below is the decision record for <TICKET>. IMMUTABLE except Revisions. Edit the living text, never this. -->`. Where it differs is frontmatter (below). When you move the record, **condense Revisions into one brief combined list** — during the task they were a running one-per-change log; the permanent doc wants the net story, not the play-by-play.

**Single file** (default) — `docs/<feature>.md`, named by feature not ticket:
- **Living top** — how the feature works now, edited freely as it changes.
- **Immutable bottom** — the decision record, keeping the ADR frontmatter (`ticket`, `status`).

**Subfolder** (multiple decisions/docs) — `docs/<feature>/`:
- `README.md` — living, how it works now (so the folder opens to it; matches `docs/clean_room/`). Put any operational "when to use / check before reusing" guidance here, not in the log — it is usage, not rationale.
- `decisions.md` — append-only decision log. **No file-level frontmatter and no status line** — a single-ticket header cannot front a multi-ticket log. Each promoted ADR is ONE entry: an `## <TICKET> — title` heading, then the record with its sections demoted one level (`## Decision` → `### Decision`). Mark a superseded entry in its heading (`## <TICKET> — title (superseded by NM-YYYY)`). If `decisions.md` already exists, **append** the new entry at the end; never overwrite an existing one.

Then, either shape:
1. **Repoint every reference to the old ADR path first.** `grep -rn '<TICKET>-<slug>' --include='*.py' --include='*.md'` and rewrite each hit (code docstrings, other docs) to the new doc path — a deleted ADR leaves dead links otherwise.
2. Delete the ADR file `docs/architectural_decisions/<TICKET>-<slug>.md` — the promoted doc is now the single source of truth.
3. Remove that ADR's line from `docs/architectural_decisions/README.md`; if that empties the index, delete the README too (seed mode recreates it for the next one-off ADR).
4. Index the new doc wherever `docs/` lists its files (a repo `CLAUDE.md` doc list counts), or add a one-line pointer if there is no index.

## Superseding

A small pivot → a Revision entry. A full reversal that outlives the task → a NEW ADR with `status: accepted`, and set the old one's frontmatter `status: superseded by NM-YYYY`. Link both in the README.
