---
ticket: NM-XXXX
title: <short decision title>
status: accepted        # accepted | superseded by NM-YYYY
---

# NM-XXXX — <short decision title>

## Context
<The situation that forced a choice. 2-4 lines. What was true, what pressure created the decision.>

<!-- IMMUTABLE below. Never edit the Decision after seed. A change goes in Revisions, or a full reversal gets a new ADR that supersedes this one. -->
## Decision
<What was chosen. State it plainly.>

## Alternatives rejected
- **<option>** — <why not>. <!-- This reasoning is the point of the ADR. Do not skip it. -->

## Constraints
<Hard limits that forced the choice: data ownership, determinism, idempotence, deadlines, upstream contracts.>

## Consequences
<What this makes easier. What it makes harder or forecloses.>

<!-- APPEND-ONLY. One entry each time the plan changes mid-implementation. Newest last. Never rewrite the Decision above. -->
## Revisions
_None yet._
<!-- Changed X to Y. Trigger: <what made the planned decision wrong>. -->

<!-- Filled at completion (finalize mode). Stays as-is until then; the finalize hook keys on the _TBD_ marker. -->
## Outcome
_TBD — filled at completion._
<!-- Net diff from the original Decision. Surprises. Final state as shipped. -->
