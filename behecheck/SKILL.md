---
name: behecheck
description: Use when the user wants a local hybrid code review — running behecheck over a git range, file paths, or raw code to get SARIF v2.1.0 findings (deterministic ast-grep rules + LLM triage/semantic review), via its CLI or MCP surface.
---

# behecheck

behecheck is the BEHEMOTION hybrid code-review layer: deterministic static analysis
(tree-sitter + ast-grep) feeding an LLM stage, emitting **SARIF v2.1.0**. It is
runtime-portable — use whichever face your runtime exposes (CLI or MCP). The LLM is
local-first and degrades gracefully when unavailable (deterministic findings still
come back).

## When to use

- The user asks to review a diff, a commit range, specific files, or a code snippet.
- The user wants machine-readable findings (SARIF) rather than prose.
- The user wants a fully local / self-controlled review (no SaaS).

## Connectivity

**MCP surface (preferred):** the beherouter gateway (or a direct `behecheck-mcp`
server) exposes these tools, all returning SARIF-shaped JSON:

| Tool | Purpose |
|------|---------|
| `review_diff(input, repo?)` | Run the pipeline. `input` is `{"kind": "git_range"\|"paths"\|"raw", …}`. |
| `explain_finding(fingerprint, input, repo?)` | Re-run and return only the matching finding. |
| `list_rules(repo?)` | List the ast-grep rule packs. |
| `health(repo?)` | Parser + rule-engine + model readiness. |
| `search(query)` | Find the right verb. |

`input` shapes:
- `{"kind": "git_range", "repo_path": ".", "rev_range": "HEAD~1..HEAD"}` (empty
  `rev_range` = working tree vs HEAD)
- `{"kind": "paths", "repo_path": ".", "paths": ["a.py"], "rev_range": null}`
- `{"kind": "raw", "files": [{"path": "a.py", "text": "…"}]}`

**CLI (verb-core):**

```bash
behecheck review --range HEAD~1..HEAD      # SARIF to stdout
behecheck review --paths src/a.py,src/b.py
behecheck review --raw-file file.py
cat file.py | behecheck review --stdin
behecheck health
behecheck explain <fingerprint> --raw-file file.py
behecheck                                  # no-arg: live readiness
```

## Reading the output

SARIF lives at `runs[0].results[]`. Each result has `ruleId`, `level`
(`error`/`warning`/`note`), `locations[0].physicalLocation` (`artifactLocation.uri`
+ `region.startLine`), a stable `fingerprints["behecheck/v1"]` (use it with
`explain`), and `properties.source` (`deterministic`|`llm`) + `properties.inDiff`.
`runs[0].invocation.executionSuccessful=false` + the `toolExecutionNotifications`
notes mean the run **degraded** (e.g. model offline) — deterministic findings are
still valid.

## Exit codes (CLI)

`0` clean · `1` findings present · `2` cannot produce a result (precondition/usage/
tool error; body is `{code, message, hint}`).

## Caveats

- The `ast-grep` binary is required for deterministic rules; if missing, only the
  LLM stage runs and a note is emitted. Check `health` first.
- The LLM stage needs a reachable local model; otherwise it is skipped (degraded).
