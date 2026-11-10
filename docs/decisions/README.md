# Decisions log

One-file-per-topic record of exploration findings and decisions made while working in this repo — distinct from `docs/01`–`docs/12` (which are static product/architecture specs). A `Stop` hook (`.claude/hooks/enforce-decision-log.sh`) blocks ending a session that explored code or exited plan mode without adding an entry here, so the next session doesn't have to re-derive the same findings.

**Before exploring a topic, check here first** — an existing entry may already cover it. If a file for this topic already exists, **update it in place** instead of creating a new one: edit the Decision/Why sections directly, or append a dated `## YYYY-MM-DD update` subsection if the decision changed. Do not create a second file for a topic that already has one — this keeps the log from accumulating duplicate/overlapping entries that bloat it to read.

## Format

File name: `<topic-slug>.md` (no date prefix — the topic, not the date, identifies the file)

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
