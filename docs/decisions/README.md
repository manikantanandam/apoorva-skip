# Decisions log

Dated, one-file-per-decision record of exploration findings and decisions made while working in this repo — distinct from `docs/01`–`docs/12` (which are static product/architecture specs). A `Stop` hook (`.claude/hooks/enforce-decision-log.sh`) blocks ending a session that explored code or exited plan mode without adding an entry here, so the next session doesn't have to re-derive the same findings.

**Before exploring a topic, check here first** — an existing entry may already cover it.

## Format

File name: `YYYY-MM-DD-<topic-slug>.md`

```markdown
# <Title>

**Date:** YYYY-MM-DD
**Context:** why this came up

## Exploration
- what was searched/read, key findings

## Decision
- what was decided

## Why
- rationale, tradeoffs, alternatives rejected
```
