---
name: handoff
description: Use when the current task is reaching a transition point and another agent (in this repo, or a related repo) needs a written handoff to continue. Reads the repo map from HANDOFF.md, composes a handoff from conversation context using template.md, and writes it into the target repo's docs/handoffs/ tree. Works in any repo layout — sibling repos under a shared parent, or child repos under an umbrella — resolving the target by probing the filesystem, not by assuming. Argument is the target slug from HANDOFF.md, `self` for the next agent on this same project, or `init` to bootstrap HANDOFF.md in a new project.
---

# /handoff

Write a structured handoff from the current task into either:

- a target repo's `docs/handoffs/from-<this-repo>/` directory, when invoked as `/handoff <target-slug>`, or
- this repo's own `docs/handoffs/self/` directory, when invoked as `/handoff self`, or
- bootstrap a fresh `HANDOFF.md` registry in this repo, when invoked as `/handoff init`.

## Repo layout — detected, never assumed

Two layouts are supported, and this skill works in both without needing a per-layout copy:

| Layout | Where targets live | Example |
|---|---|---|
| **Sibling** | `../<slug>` — all participating repos share a parent directory | `~/Repo/BEHEMOTION/beheaxi` → `~/Repo/BEHEMOTION/beherouter` |
| **Umbrella** | `./<slug>` — the current repo *contains* the targets as subdirectories | `~/Repo/BEHEMOTION` → `~/Repo/BEHEMOTION/beherouter` |

**Always resolve by checking the filesystem** (§3), never by assuming which layout you are
in. A single installed copy of this skill serves every repo in both roles: the umbrella repo
resolves its targets as children, and each child resolves its peers as siblings — the same
instructions, different answers, because the probe is what decides.

> **Why this matters:** this skill was previously maintained as two hardcoded variants, a
> sibling one and an umbrella one. A distribution run copied the umbrella variant into 8
> child repos, where `./<slug>` can never resolve — silently, since the skill still loaded
> and still ran. Probing removes the entire class of failure. Do not reintroduce a variant.

The skill is intended to be runtime-portable: instructions are phrased as plain actions (read X, write X, ask the user) so the same skill folder works under Claude Code, OpenCode, pi, and other agents that load `SKILL.md`-style skills. Where this document says "ask the user (a) / (b) / (c)", use whatever interactive primitive your runtime offers — a structured question UI, an inline prompt, or plain text Q&A.

## Step 0 — Branch on the argument

- **`init`** → run the **Init flow** below. Stop after.
- **No argument**, `self`, or any other value → run the **Handoff flow** below.

---

## Init flow

Use this when the user runs `/handoff init`. The goal is to produce a working `HANDOFF.md` at the repo root so subsequent `/handoff <target>` and `/handoff self` calls work. Safe for both greenfield (no docs structure) and brownfield (existing `docs/`) projects.

### I.1. Detect existing HANDOFF.md

Check for `./HANDOFF.md` at the repo root.

- **If present:** ask the user — (a) keep existing (cancel init), (b) overwrite, (c) cancel. Act on the answer. If (a) or (c), stop.
- **If absent:** proceed.

### I.2. Determine this repo's slug

Compute the default slug as the basename of the current working directory. Ask the user to confirm or override. The slug is case-sensitive and should equal the repo's directory name on disk (cross-repo path resolution depends on this).

Call the result `SELF_SLUG`.

### I.3. Determine topology

Ask the user — (a) **single-repo project** (only `/handoff self` will be used), or (b) **multi-repo project** (this repo participates with other repos, either as siblings under a shared parent or as children under this one).

Note that (b) covers both layouts and you do **not** need to record which: the Repository map stores slugs only, and §3 probes for the directory at handoff time. A repo can even be both — an umbrella whose children are each other's siblings.

### I.4. If multi-repo, gather the other repos

For each participating repo, ask the user for:

- **Slug** (must equal that repo's directory name on disk, case-sensitive)
- **Tag** (optional short label, e.g. project key — use `—` if none)
- **Purpose** (one-line description)

Repeat until the user is done. The current repo (`SELF_SLUG`) is implicitly included; do not ask for it.

### I.5. Read the registry template

Read `<this-skill-folder>/HANDOFF.template.md`. This file contains the canonical structure with `<SELF_SLUG>` and `<REPO_MAP_ROWS>` placeholders.

The skill folder may be installed **user-level** (`~/.claude/skills/handoff/`, `~/.config/opencode/skills/handoff/`, …) or **project-level** (`.claude/skills/handoff/`, `.opencode/skills/handoff/`, …). Use whichever path the running agent loaded this file from — under Claude Code that is `${CLAUDE_SKILL_DIR}`. **User-level is the preferred install** and takes precedence: a user-level skill shadows a project-level one of the same name, silently and with no warning.

### I.6. Compose HANDOFF.md

Take the template content and:

1. Replace every `<SELF_SLUG>` with the chosen slug.
2. Replace `<REPO_MAP_ROWS>` with the table body, one row per repo as `` | `<slug>` | <tag> | <purpose> | `` (slug in backticks — `sync.sh` parses them):
   - **Single-repo mode:** only the `SELF_SLUG` row.
   - **Multi-repo mode:** one row per repo gathered in I.4, plus the `SELF_SLUG` row. Write purposes that read correctly from *any* repo (the same rows are distributed everywhere), not "This repo".

### I.7. Write files

- Write the composed content to `./HANDOFF.md` (overwrite if I.1 said overwrite).
- Create the handoff tree if it doesn't exist:
  ```
  mkdir -p ./docs/handoffs/self
  ```
  This step is safe for brownfield projects — it does not touch any existing docs.

### I.8. Report

Tell the user:

- The slug used.
- The topology (single-repo, or multi-repo with N participating repos).
- The path written: `./HANDOFF.md`.
- Next steps:
  - Single-repo: "Use `/handoff self` to write a handoff to the next agent on this project."
  - Multi-repo: "Use `/handoff <slug>` for another repo, or `/handoff self`. Each participating repo needs its own `HANDOFF.md` — run `/handoff init` in each, or distribute them with `bash <skill-folder>/scripts/sync.sh`."

> **What `sync.sh` distributes.** It writes a generated `HANDOFF.md` (same Repository map
> everywhere) into every participating repo, and installs the *canonical* copies of the
> workflow skills (`handoff`, `land-clean`, `deploy`) from beheskills into each repo's
> `.claude/skills/` (and `.opencode/skills/` where present). Because this skill probes
> instead of assuming a layout, every copy is identical and correct in every repo — the old
> failure (an umbrella-only variant copied into 8 children) cannot recur. Never install a
> copy edited for one repo into another; a repo-specific skill marks itself with
> `<!-- beheskills: local -->` and is skipped.

Stop.

---

## Handoff flow

Use this for any argument other than `init` (including no argument and `self`).

### 1. Read `HANDOFF.md`

Read `./HANDOFF.md` from the current repo's root.

- Locate the **What this repo is** block. Extract the value of the `Slug:` field — call it `SELF_SLUG`. This is the source slug.
- Locate the **Repository map** table. Each row gives a target slug (column 1, wrapped in backticks) which is also that repo's **directory name on disk**. The map records the name only — where that directory sits relative to the current repo is resolved by probing in §3.

If `HANDOFF.md` is not found, ask the user — (a) run `/handoff init` now to bootstrap, (b) cancel. If (a), invoke the Init flow above and then stop (do not auto-continue into the Handoff flow; let the user re-run `/handoff <target>` once init is done). If (b), stop.

If `HANDOFF.md` exists but is missing the **What this repo is** block, report: "HANDOFF.md is malformed (missing 'What this repo is' block). Re-run `/handoff init` to regenerate, or fix manually." Stop.

### 2. Resolve the argument

The user passed an argument (or no argument).

- **No argument** → print the Repository map and ask the user which target. Stop.
- **Argument is `self`** → target dir is `.`, source-bucket is `self/`.
- **Otherwise** → look for an exact case-sensitive match in the Slug column of the Repository map.
  - **Match found** (and slug ≠ `SELF_SLUG`): the target directory is resolved by probing in §3 — do **not** assume a path here. Source-bucket is `from-<SELF_SLUG>/`.
  - **Match found but slug = `SELF_SLUG`**: same as `self`.
  - **No match**, **and** the Repository map has no target rows (single-repo mode): report: "Single-repo mode — only `/handoff self` is available. To add targets, edit HANDOFF.md's Repository map and re-run." Stop.
  - **No match** otherwise: print the Repository map and ask the user which target they meant. Stop.

### 3. Resolve the target directory by probing the filesystem

For `self`, the target directory is the current working directory. Skip the rest of this step.

Otherwise, check the candidate paths **in this order** and take the first that exists and is
a directory:

1. `./<matched-slug>` — **umbrella layout**: the target is a child of the current repo.
2. `../<matched-slug>` — **sibling layout**: the target shares a parent with the current repo.
3. `..` — **parent layout**: the target *is* the parent directory (its basename equals
   `<matched-slug>`). This is how a child reaches its umbrella, e.g. `/handoff BEHEMOTION` from
   `~/Repo/BEHEMOTION/behemem`.

Child is checked first because it is unambiguous: if `./<slug>` exists, the current repo
demonstrably contains the target, and no sibling of the same name could be the intended one.

**If more than one exists**, that is genuinely ambiguous — print both paths and ask the user which they
meant. Do not guess.

**If none exists**, report: "Target `<slug>` not found at `./<slug>`, `../<slug>` or as the parent directory
(from `<cwd>`). This skill supports two layouts: participating repos cloned as siblings under
a shared parent, or as children under an umbrella repo. Clone the target into one of those
positions, or fix HANDOFF.md's Repository map if the layout has changed." Stop.

Report the resolved path in the final output (§9) so the user can see which layout was
detected.

### 4. Pick a TOPIC slug

From recent conversation context, compose an UPPER-KEBAB-CASE topic that names the *thing being handed off*, not the activity.

- Good: `TURNS-AGENTIC-STREAM-URL-500`, `SCHEMA-PARITY-PRODUCT-FAMILY`, `VOICE-STT-LANGUAGE-DETECTION`
- Bad: `FIXING-TURNS-BUG`, `WORKING-ON-SCHEMA`

3 to 8 words. If no clear topic emerges from context, ask the user.

### 5. Compute the target path

Target path: `<target-dir>/docs/handoffs/<source-bucket>/<TOPIC>.md`

Create the directory if it doesn't exist:

```
mkdir -p <target-dir>/docs/handoffs/<source-bucket>
```

### 6. Check for collision

If a file already exists at the target path:

- Print the existing path.
- Ask the user — (a) supersede this file, (b) write a `-PART2.md` follow-up (or `-PART3`, etc.), (c) cancel.
- Act on the answer. If (a), proceed to overwrite. If (b), append `-PART2` (or the next free number) before `.md`. If (c), stop.

### 7. Read the body template

Read `<this-skill-folder>/template.md`. Use it as the structural skeleton.

The five required sections must be present in the output: **Context**, **What's needed**, **Affected code / surfaces**, **Verification**, **Open questions**.

Optional sections (Timeline, Smoke-test fixture, Appendix, etc.) are listed in HTML comments inside the template — keep the ones that apply, delete the rest.

### 8. Fill the template

Compose the handoff content from conversation context:

- **Title:** one-line description of what this handoff declares or asks for.
- **From / To / Date / Status:** From is `SELF_SLUG`, To is the resolved target slug (or `self`), Date is today's date in `YYYY-MM-DD`, Status is `Open` for new handoffs.
- **Context:** Why this handoff exists; what background the target needs.
- **What's needed:** The specific ask. Wire shapes, contract changes, fixes, questions.
- **Affected code / surfaces:** File paths with line numbers (e.g. `apps/turns/views.py:140`); URLs; container names; deploy targets.
- **Verification:** How the target proves the handoff is satisfied. Concrete commands or smoke tests. If there's no objective verification, say so.
- **Open questions:** Things you're unsure about; the target may push back.
- **Sign-off (last line):** `— <SELF_SLUG> team, <YYYY-MM-DD>`

Be specific and operational. Avoid vague "follow up on X" phrasing.

### 9. Write the file and report

Write the composed content to the target path.

Report to the user:

- The full path written: `<target-dir>/docs/handoffs/<source-bucket>/<TOPIC>.md`
- A reminder: "Review and commit in `<target-dir>` when ready. The target's git tree was modified directly."
