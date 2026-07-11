---
name: code-intent-layering
description: Guidance for applying intent layering across code, tests, commit messages, and code comments. Use when reviewing, writing, or refactoring implementation code, tests, commit logs, review feedback, or comments to keep code focused on How, tests focused on What, commits focused on Why, and comments focused on Why-not or non-obvious Why.
---

# Code Intent Layering

## Overview

Use intent layering to put each kind of information where future maintainers are most likely to look for it:

- **Code: How** the behavior is implemented.
- **Tests: What** behavior must hold.
- **Commit logs: Why** the change was made.
- **Code comments: Why-not**, and sometimes **Why**, when the reason is local, surprising, or easy to lose.

This is a heuristic, not a ban. Prefer the default layer, then make exceptions when removing context would make the system harder to maintain.

## Workflow

1. Identify the artifact being written or reviewed: implementation code, test code, commit message, or code comment.
2. Ask which intent belongs there by default.
3. Move misplaced context to a better layer when possible.
4. Keep exceptions only when the context must be visible at the local decision point.

## Layer Rules

### Code: How

Make implementation code show the mechanism clearly:

- Prefer readable names, small functions, and explicit control flow over explanatory comments.
- Let domain terms and types carry intent where possible.
- Avoid encoding broad product rationale in implementation bodies unless it directly affects the algorithm.

### Tests: What

Make tests specify observable behavior:

- Name tests by the condition and expected result.
- Assert outcomes, invariants, contracts, and edge cases.
- Avoid duplicating implementation details unless the test intentionally pins a low-level contract.

### Commit Logs: Why

Make commits explain the motivation and tradeoff behind the diff:

- State the user, product, operational, or technical reason for the change.
- Include the bug, constraint, regression, incident, or migration pressure when relevant.
- Do not merely summarize the diff; the diff already shows what changed.

### Code Comments: Why-not, plus Local Why

Use comments mainly for decisions that are not obvious from the code:

- Explain **Why-not**: rejected alternatives, dangerous simplifications, historical traps, compatibility constraints, performance cliffs, ordering dependencies, or security boundaries.
- Also explain **Why** when the reason must be read next to the code to prevent an incorrect edit.
- Delete comments that only restate the code's How.
- Prefer comments that describe the constraint, not the author’s thought process.

Good comment prompts:

- “Why can’t this be simpler?”
- “What future change would break this?”
- “What alternative will a maintainer probably try, and why is it wrong here?”
- “What local rationale is not recoverable from names, tests, or commit history?”

## Review Checklist

Use this checklist during implementation or review:

- Code answers **How** without needing comments that paraphrase statements.
- Tests answer **What** users or callers can rely on.
- Commit messages answer **Why now** and **why this direction**.
- Comments answer **Why-not** or a local **Why** that would otherwise be lost.
- Any duplicated explanation is intentional and valuable at the point of use.

## Commit Message Pattern

Use this shape when asked to draft commits:

```text
<imperative summary of change>

Explain why the change is needed, what constraint or problem it addresses,
and why the chosen direction is appropriate. Mention notable rejected options
only when they matter for future maintenance.
```
