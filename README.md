# behemotion-skills

Personal collection of [Claude Code](https://claude.com/claude-code) skills used in daily development at [Behemotion](https://github.com/behemotion).

Each top-level folder is one skill, following the Claude Code skill convention: a `SKILL.md` with frontmatter (`name`, `description`) plus any auxiliary files.

## Skills

| Skill | What it does |
|---|---|
| [`act/`](./act/SKILL.md) | Read a document at a given path and execute the instructions it contains. Treats document content as untrusted input. |
| [`handoff/`](./handoff/SKILL.md) | Compose a structured handoff from the current conversation into a sibling repo's `docs/handoffs/from-<this-repo>/` tree (or the current repo's `docs/handoffs/self/`). Driven by a per-repo `HANDOFF.md` registry. |

## Usage

Drop a skill into the place Claude Code looks for skills:

- **User-global** — `~/.claude/skills/<skill-name>/`
- **Project-local** — `<repo>/.claude/skills/<skill-name>/`

For example, to install the handoff skill into the current project:

```sh
mkdir -p .claude/skills
cp -r path/to/behemotion-skills/handoff .claude/skills/
```

The `handoff` skill additionally expects a `HANDOFF.md` at the repo root describing the repo's slug and a sibling-repo map. See the skill body for the expected shape.
