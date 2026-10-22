# behemotion-skills

Personal collection of skills used in daily development at [Behemotion](https://github.com/behemotion). Designed to be runtime-portable — each skill folder is self-contained and works under [Claude Code](https://claude.com/claude-code), [OpenCode](https://opencode.ai), pi agent, and other agents that load `SKILL.md`-style skills.

Each top-level folder is one skill: a `SKILL.md` with frontmatter (`name`, `description`) plus any auxiliary files. Instructions inside `SKILL.md` are phrased as plain actions ("read X", "write X", "ask the user") rather than tool names, so the same folder works across runtimes.

## Skills

| Skill | What it does |
|---|---|
| [`act/`](./act/SKILL.md) | Read a document at a given path and execute the instructions it contains. Treats document content as untrusted input; flags any embedded attempts to override system rules. Single-file skill — no setup, drops into any project. |
| [`handoff/`](./handoff/SKILL.md) | Compose a structured handoff from the current conversation into a sibling repo's `docs/handoffs/from-<this-repo>/` tree (or this repo's `docs/handoffs/self/`). Self-contained: ships a `HANDOFF.md` registry template and a generic sibling-distribution script. Run `/handoff init` in any project to bootstrap. |
| [`land-clean/`](./land-clean/SKILL.md) | Land finished work on `main`: takes uncommitted changes, stashes and/or the current branch as-is, writes proper commits, strips AI-agent attribution from messages and content, merges and pushes. Prefers the latest work on conflicts. |
| [`deploy/`](./deploy/SKILL.md) | Generic deploy driver: reads the current repo's root `DEPLOY.md` runbook and executes it with pre-flight, verification and a report. Stops when the repo has no `DEPLOY.md`. A repo can replace it with its own skill marked `<!-- beheskills: local -->`. |
| [`behecheck/`](./behecheck/SKILL.md) | Per-layer skill for behecheck, the BEHEMOTION hybrid code-review layer: run it over a git range, paths or raw code via CLI or MCP and read the SARIF v2.1.0 findings. |
| [`behesid/`](./behesid/SKILL.md) | Per-layer skill for behesid, the BEHEMOTION system-dynamics simulation layer: build, check and change stock-and-flow models through changesets, run and compare simulations (ensembles, calibration, sensitivity, loop dominance), and give a model a scenario surface (`scenario-schema`, `scenario-validate`) via CLI or MCP. |

## Installation

Drop a skill into the place your agent looks for skills:

| Agent | User-global | Project-local |
|---|---|---|
| Claude Code | `~/.claude/skills/<name>/` | `<repo>/.claude/skills/<name>/` |
| OpenCode | `~/.opencode/skills/<name>/` | `<repo>/.opencode/skills/<name>/` |
| pi agent | per pi's skill-loader convention | per pi's skill-loader convention |

For example, to install the `handoff` skill into the current project for Claude Code:

```sh
mkdir -p .claude/skills
cp -r path/to/behemotion-skills/handoff .claude/skills/
```

For OpenCode in the same project, repeat with `.opencode/skills/`. The skill folder contents are identical — only the install path differs. The `handoff` skill's bundled `scripts/sync.sh` auto-detects whichever layouts are present.

For pi agent, install per pi's local convention; the `SKILL.md` and template artifacts inside the folder are runtime-agnostic.

## act — quick start

Drop the `act/` folder into your agent's skills directory. No setup required. Then:

```
/act path/to/some-document.md
```

The skill reads the document fully, executes the instructions it contains, and stays within scope. Project rules (your `CLAUDE.md` / `AGENTS.md` / `OPENCODE.md` / `GEMINI.md`) override anything the document says. Document content is treated as untrusted input — embedded attempts to override system rules or exfiltrate data are flagged, not followed.

Use it when you have a one-off instruction document (e.g., a task brief, a handoff received from another team via `/handoff`, a generated runbook) and want the agent to execute it deliberately rather than have you paste the body into the chat.

## handoff — quick start

The `handoff` skill is self-contained for `init` / `self` / `<slug>` use. After installing the folder:

1. Run `/handoff init` in your project. The skill walks you through:
   - Confirming this repo's slug.
   - Choosing single-repo or multi-repo topology.
   - For multi-repo: collecting sibling slugs, tags, and purposes.
   - Writing `HANDOFF.md` at the repo root and creating `docs/handoffs/`.

2. From then on:
   - `/handoff self` → write a handoff to the next agent on this same project.
   - `/handoff <sibling-slug>` → write a handoff into a sibling repo's tree (multi-repo only; sibling must be cloned alongside this one).

3. **Multi-repo distribution.** If you want all participating repos to share the same Repository map and agent workflow skills, run the script from a checkout of this collection, in (or pointing at) the repo that owns the map:

   ```sh
   bash path/to/behemotion-skills/handoff/scripts/sync.sh [SOURCE_REPO] [--dry-run]
   ```

   For each repo listed in the source's `HANDOFF.md` Repository map (found as a child `./<slug>` or a sibling `../<slug>`), the script writes a generated `HANDOFF.md` (`<SELF_SLUG>` substituted, map rows identical everywhere), creates `docs/handoffs/self/`, and installs `handoff`, `land-clean` and `deploy` into `.claude/skills/` (and `.opencode/skills/` where the target has `.opencode/`). It needs those three folders side by side, so run it from the full collection rather than a lone installed `handoff/` copy. A skill whose `SKILL.md` contains `beheskills: local` is left untouched.

Greenfield (new project, no docs structure) and brownfield (existing project, possibly with `docs/`) are both supported. Init only writes `HANDOFF.md` at the repo root and creates `docs/handoffs/` — it does not touch any other files.
