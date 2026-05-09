---
name: handoff
description: Use when the current task is reaching a transition point and another agent (in this repo or a sibling repo) needs a written handoff to continue. Reads the repo map from HANDOFF.md, composes a handoff from conversation context using template.md, and writes it into the target repo's docs/handoffs/ tree. Argument is the target slug from HANDOFF.md, or `self` for the next agent on this same project/task.
---

# /handoff

Write a structured handoff from the current task into either:

- a sibling repo's `docs/handoffs/from-<this-repo>/` directory, when invoked as `/handoff <target-slug>`, or
- this repo's own `docs/handoffs/self/` directory, when invoked as `/handoff self`.

Follow the procedure below in order.

## Procedure

### 1. Read `HANDOFF.md`

Read `./HANDOFF.md` from the current repo's root.

- Locate the **What this repo is** block. Extract the value of the `Slug:` field — call it `SELF_SLUG`. This is the source slug.
- Locate the **Repository map** table. Each row gives a target slug (column 1) which is also the directory name relative to the parent dir of the current repo.

If `HANDOFF.md` is not found or is missing the **What this repo is** or **Repository map** section, stop and report: "HANDOFF.md not found or malformed in repo root — is this repo set up for handoffs?"

### 2. Resolve the argument

The user passed an argument (or no argument).

- **No argument** → print the Repository map and ask the user which target. Stop.
- **Argument is `self`** → target dir is `.`, source-bucket is `self/`.
- **Otherwise** → look for an exact case-sensitive match in the Slug column.
  - Match found: target dir is `../<matched-slug>` (relative to the current repo). Source-bucket is `from-<SELF_SLUG>/`.
  - No match: print the Repository map and ask the user which target they meant. Stop.

### 3. Verify the target directory exists

Confirm the target directory is on the filesystem.

- For `self`: the current working directory.
- For a sibling: `../<matched-slug>` relative to the current repo.

If the target directory does not exist, report: "Target `<slug>` not found at `<path>`. The handoff convention expects all participating repos to be cloned as siblings under a single parent directory. Clone the target alongside this repo or adjust the layout." Stop.

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
- Ask the user: "(a) supersede this file, (b) write a `-PART2.md` follow-up (or `-PART3`, etc.), (c) cancel."
- Act on the answer. If (a), proceed to overwrite. If (b), append `-PART2` (or the next free number) before `.md`. If (c), stop.

### 7. Read the template

Read `./.claude/skills/handoff/template.md`. Use it as the structural skeleton.

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
