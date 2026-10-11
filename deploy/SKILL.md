---
name: deploy
description: Use when a release of the current repo is ready to ship to its live host or artifact registry. Generic runbook driver — reads this repo's root DEPLOY.md (the canonical runbook per BEHEMOTION CONVENTIONS §11) and executes it with pre-flight, verification and a report. Stops when the repo has no DEPLOY.md, i.e. is not deployable.
---

# /deploy

Ship one release of **the current repo** by following its own runbook, `DEPLOY.md` at the repo
root. This skill is the checklist around that runbook; it carries no repo-specific steps. A repo
whose deployment needs more than its runbook can say replaces this skill with its own
`.claude/skills/deploy/SKILL.md` containing the line `<!-- beheskills: local -->`, and
`sync.sh` then leaves it alone.

Runtime-portable: every instruction is a plain action (run X, check Y, ask the user).

## Step 0 — Never do these

- **Never deploy without a runbook.** No `DEPLOY.md` at the repo root → stop and tell the user the
  repo is not deployable (its `AGENTS.md` "Repo docs" table says why). Do not improvise a deploy
  from `README.md`, compose files or memory.
- **Never deploy from a dirty or unpushed tree.** `git status --short --branch` must be clean, on
  the branch the runbook names (default `main`), and level with its remote. Unlanded work → run
  `/land-clean` first.
- **Never put a secret anywhere but where `DEPLOY.md` § Configuration & secrets says it lives.** No
  values in commands you echo, in tracked files, or in the report.
- **Never bump minor or major without the user's explicit approval.** Patch only by default.
- **Never skip Verify.** A deploy without the runbook's verification steps is not done.

## Step 1 — Read

1. Read `DEPLOY.md` fully. Then read `CONNECTIONS.md` § Runs on (host, runtime, SSH access) and
   `AGENTS.md` § Build / test.
2. If `DEPLOY.md` disagrees with `CONNECTIONS.md`, the code (ports, image names, manifests) or
   the umbrella's `docs/CONVENTIONS.md` §7 — stop and show the user the contradiction before
   touching anything.

## Step 2 — Pre-flight

1. Run the suite exactly as `AGENTS.md` § Build / test lists it (it mirrors CI). Red → stop.
2. If the repo ships a beheaxi CLI: `uv run beheaxi conformance "<slug>" --json` exits 0.
3. Version consistency: every place the runbook names (pyproject, chart, CHANGELOG heading, tag)
   carries the same new version.

## Step 3 — Deploy

Execute `DEPLOY.md` § Deploy step by step, in order. Show each command before running it when it
mutates a remote host, registry or cluster. Pause and ask on anything the runbook marks as
destructive (migrations, data moves, credential rotation).

## Step 4 — Verify

Execute `DEPLOY.md` § Verify. At minimum: the health endpoint answers `{"status": "ok"}` and the
release's headline change works once through the live surface. Failure → `DEPLOY.md` § Rollback,
then report.

## Step 5 — Report

Version shipped, commands run (no secret values), verification output, anything skipped and why,
and the rollback path. If the runbook was wrong or incomplete, say exactly where and propose the
`DEPLOY.md` edit — the runbook is fixed in the repo, not worked around.
