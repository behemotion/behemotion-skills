---
name: behesid
description: Use when building, changing, checking or simulating a system dynamics model with behesid — over MCP (behesid_* tools) or the behesid CLI. Orient with inspect and loops, change the model only through apply, verify with validate and run, and hand the change to a human for review.
---

# behesid

behesid is a system dynamics engine and agent toolkit. A model is a directory of YAML files
(`model.yaml`, one file per element under `sectors/<sector>/`, plus dimensions, assumptions and
references). behesid is the only writer of those files: every change goes through a changeset
that is checked before anything is written, so a broken model is never written.

## When to use

- You are asked to build, extend, correct or explain a stock-and-flow model.
- You need simulation results (a run, a time series, a comparison of parameter settings).
- You are importing a Vensim `.mdl` or XMILE model, or exporting XMILE.
- You are giving a model a scenario surface (levers, outputs, scenarios) so an application
  can let end users ask "what if", or checking a request such an application built.
- Not for statistics on raw data, and not for editing model files by hand: never write a model
  file yourself, always use `apply`, `rename` or `fix-refs`.

## Connectivity

- **MCP:** tools are named `behesid_<verb>` (`fix-refs` is `behesid_fix_refs`). Start the server
  with `behesid-mcp` (stdio, the default) or `behesid-mcp --transport http`, which listens on
  `127.0.0.1:47160` at `/mcp` and needs `Authorization: Bearer $BEHESID_MCP_TOKEN`;
  `GET /healthz` answers without a token. Through the BEHEMOTION gateway the tools keep their
  names. The server works on one model directory, set when it starts; tools take no
  `model_dir`.
- **CLI:** `behesid <verb> --json` prints exactly one JSON document. Flags are the argument
  names below with hyphens (`max_length` is `--max-length`); a list argument repeats its flag.
- **Configuration:** defaults < `.behesid.toml` < `BEHESID_*` environment < arguments. Keys:
  `model_dir` (`model`), `store_dir` (`.behesid`), `backend` (`numpy`), `default_budget_s`
  (100), `mcp_host`, `mcp_port`. The token is read from `BEHESID_MCP_TOKEN` only.

## Workflow

1. **Orient.** `skill` (this text), `language` (equation grammar, builtins with their unit
   rules, file schemas, check rules), `inspect` (model summary; then the elements you care
   about with `depth`), `loops` (feedback structure), `trace` (what drives what).
2. **Change.** Open a workspace (`workspace` with `action: open`) and pass its id as
   `workspace_id` from then on. Write a changeset, send it with `apply` and `dry_run: true`,
   read `introduced` findings and the `diff`, fix the changeset, then `apply` it for real;
   each write is one commit on the workspace's branch. Use `rename` to change an element's
   id and `fix-refs` after a merge leaves stale names. Put the `hash_after` you last saw in
   the changeset's `expect_hash` field, so a concurrent edit is a conflict instead of a lost
   update.
3. **Verify.** `validate` (`level: full` before handing off), `run`, then `series` for the
   lines you need, `compare` for runs side by side, and `diff` against the base. Fit
   constants to data with `calibrate` and apply its `ops` like any changeset; find what
   matters with `sensitivity`, and which loops drive the behaviour, and when, with `dominance`.
4. **Hand off.** `review` the workspace and give the human its `review_md` path, the risk
   `tier`, the remaining findings and the `tag_command`. The human merges the branch with
   `--no-ff`, runs `validate --level full` on the result and tags it; you never tag or merge.
   Load a baseline only after `verify-baseline` says `ok`.

A changeset is a JSON (or YAML) document:

```json
{"reason": "add a cooling cup", "sources": ["ref_newton"],
 "ops": [
  {"op": "create", "element": {"id": "room", "kind": "const", "sector": "cup",
   "units": "degree", "value": "20", "references": ["ref_newton"]}},
  {"op": "update", "id": "cooling", "set": {"eqn": "(temperature - room) / cooling_time"}},
  {"op": "connect", "flow": "cooling", "from": "temperature"},
  {"op": "delete", "id": "old_rule"}
 ]}
```

Ops: `create` (one of `model`, `dimension`, `element`, `assumption`, `reference`, `lever`,
`output`, `scenario`), `update`
(`set` replaces whole fields, `unset` removes them; `kind` names a non-element), `delete`,
`connect`/`disconnect` (a flow's `from`/`to`; `null` is a cloud), `set-dims`, `move-sector`,
`rename`. All ops apply together or not at all. Numbers keep their spelling (`0.10` stays
`0.10`).

### The scenario surface

End users never touch structure: an application lets them change **levers** and ask about
**outputs**, which you describe as model files through `apply` like any other object.

- A `lever` (`levers/<id>.yaml`) overrides a constant parameter or an aux (`target`) at the
  dims a request may address, in its `units` (they must convert to the target's), inside
  `bounds`, with the `profiles` it allows (`constant`, `step`, `window`, `ramp`) and a
  `default_profile`. Give it `label`s and `synonyms` per language: they are how a small model
  finds it. A constant a computed constant reads takes only the constant profile.
- An `output` (`outputs/<id>.yaml`) reports a stock, flow or aux (`element`) in `units` it
  converts to, with the `aggregations` a question may ask (`end_of_period`, `mean`, `min`,
  `max`, `total` for a rate, `first_below`/`first_above` with named `thresholds`) and how cells
  of dims outside `by` `combine` (`sum`, `mean`, `min`, `max`).
- A `scenario` (`scenarios/<id>.yaml`) holds lever settings (`lever`, `at`, `profile`, `from`,
  `to`, `value`) and `uncertainty` (per lever: `normal`, `lognormal`, `uniform`, `triangular`,
  `discrete` or `event`), on top of the scenario it `extends`.

`validate` checks them (LEVER, OUTPUT and SCEN rules); `scenario-schema` shows what an
application will offer, and `scenario-validate` checks a request against it.

## Modelling checks

Before you call a model done, work through Sterman's checks and say what you did:

- **Boundary adequacy:** are the important feedbacks inside the model, and what is exogenous?
- **Structure verification:** does each stock, flow and equation match how the system works?
  Use `loops` and `trace` to explain the structure.
- **Dimensional consistency:** `validate` must report no unit errors; never silence one by
  changing units without a reason.
- **Extreme conditions:** run with parameters at extremes (`run` with `set`) and check stocks
  stay meaningful (no negative inventories, no runaway growth that cannot happen).
- **Behaviour reproduction:** compare runs with the reference behaviour you were given, and say
  where they differ.

## Rules

- **Never fabricate data.** A parameter value comes from a cited source or is marked as an
  assumption (an `assumption` object with a `statement` and a `rationale`).
- **Cite sources.** Create `reference` objects for documents, experts and data, list them in the
  elements' `references`, and name them in the changeset's `sources`.
- **Never touch baselines.** Do not edit model files directly, do not tag or merge, and do not
  rewrite history; changes go through `apply`, `rename` and `fix-refs` only.
- Keep each changeset to one purpose, with a `reason` a reviewer understands.

## Reading the output

- Every result is a JSON object. Domain failures are data: `ok: false` with `findings` (or
  `introduced` and `existing` for writes), never an error.
- A finding has `rule_id`, `severity` (`error`, `warning`, `info`), `message`, `fix` and, when
  known, `element`, `file`, `line` and `hint`. `language` lists every rule.
- `format: concise` (the MCP default) keeps 20 findings, errors first, and 50 of any other list
  (series lines and levels of elements included), gives each cut list's full count in
  `<list>_total`, drops `doc` text and the compiled source, and cuts a diff to its first 20
  changes. Ask for `format: detailed` (the CLI default) when you need everything.
- Errors come back as a tool error (MCP) or on stderr (CLI) as
  `{"error": {"type", "title", "detail", "code", "context"}}`; `type` is `usage`, `not_found` or
  `conflict` (or `internal` for a failure behesid did not expect). `context.did_you_mean`
  suggests names when one was not found.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | Done |
| 2 | Usage: a bad argument or a changeset that cannot apply (`context.op` names the op) |
| 3 | Not found: the model directory, an element, a run id, a file |
| 5 | Conflict: `expect_hash` is stale, or another writer holds the model |
| 10 | Findings: `validate`, `run`, `calibrate`, `sensitivity`, `dominance` or `convert` found errors, `fmt --check` found files to rewrite, a write was refused because the result had errors, `scenario-validate` gave hints, or a scenario verb's model does not pass quick validation |
| 11 | Simulation error: the run (of `run`, at `calibrate`'s estimates, of `sensitivity`, of `dominance` or of `loops` with `numeric`) has SIM findings (division by zero, NaN) |
| 12 | Budget exhausted: `run`, `calibrate`, `sensitivity`, `dominance` or `loops` with `numeric` outlasted `budget_s`; nothing was stored |
| 13 | Stale workspace: `review` found a newer `baseline/vN` than the workspace's base; refresh it |

Over MCP the same outcomes arrive as `ok: false` data (10–13) or tool errors (2, 3, 5).

## Caveats

- `run` over MCP has a budget of `default_budget_s` seconds (100) unless you pass `budget_s`.
  The budget covers the time loop, checked every 1000 steps, not compilation; an exhausted run
  has no `run_id`. A cached run (same model, settings and outputs) returns at once whatever the
  budget.
- Series never return in full: `run` gives summaries and `run_dir`; ask `series` for at most
  `max_points` points per line (min/max downsampled above that).
- Dimension and dimension-element renames are not supported; `rename` renames elements.
- Data bindings (`bind`) arrive in a later release; until then constants carry their values.
- Scenario packs arrive in a later release; until then `review`'s before/after run is the
  model's default run.
- Workspaces need the model directory in a git work tree; outside one, writes still happen
  and `commit.committed` is false.

# Verbs

## inspect

The model summary (id, time, counts, sectors, dimensions, `model_hash`), or with `elements` each
element's equation, units, doc, provenance, upstream to `depth` levels and `used_by`.
`compiled: true` adds the generated code and parameter layout. CLI: `--element` repeats. `workspace_id` works in that workspace instead (see `workspace`).

## loops

Feedback loops, each with its elements, link polarities and loop polarity (`positive`,
`negative`, `unknown`). `containing` keeps loops through one element; `max_length` and `limit`
bound the search; `truncated_by` says why it stopped early. A link is `?` when its sign cannot
be proved from the equations (an `IF` on the source, `SIN`, `MOD`, ...); with `numeric: true`
one run at the model's values gives each `?` link the sign its effect showed (`+` or `-` when it
never changed sign; otherwise it stays `?`), `numeric` marks those links, and `findings` holds
the run's SIM findings (`ok: false`, exit 11). `budget_s` bounds that run (over it the signs stay
`?`, `budget_exhausted`, exit 12). A numeric sign is what the run did, not a proof: check it at
other values. `workspace_id` works in that workspace instead (see `workspace`).

## trace

Causal paths from `element` to `to` (shortest first); without `to`, every element it reaches by
distance; with `upstream: true`, what it depends on, plus the assumptions, references and data
bindings behind it. `max_length` and `limit` bound the paths. `workspace_id` works in that workspace instead (see `workspace`).

## search

Elements matching `text` (in ids, labels, units, docs, equations and values; each match names
its `fields`), `kind`, `sector`, `tag` or `dimension`, at most `limit`, with `total` and
`truncated`. `workspace_id` works in that workspace instead (see `workspace`).

## validate

The check catalogue at `level: quick` (schema, references, units, dimensions, graph) or `full`
(the documentation checks too). `ok` is false when there is an error; `counts` tallies by
severity. `workspace_id` works in that workspace instead (see `workspace`).

## fmt

Rewrites model files in canonical form under the model lock. `check: true` only reports the
files that would change (`ok: false` when any would). Files that do not parse are listed in
`unparseable`, left alone, and make `ok` false. A rewrite is committed as `apply`'s writes are
(`agent`, `session`, `llm_model`; reason "canonical form"). `workspace_id` works in that workspace instead (see `workspace`).

## apply

Applies a changeset — `text` (the document itself; over MCP always this) or `file` (a path the
server reads). The ops apply in memory; `validate --level quick` runs on the result; the files
are written only when it reports no error. `dry_run: true` does everything but the write.
Output: `ok`, `written`, `hash_before`/`hash_after`, `writes`, `deletes`, `introduced` and
`existing` findings, `rewrites` and the semantic `diff`. CLI: without `--file` it reads stdin.
In a git work tree the written paths, and only those, are committed at once: the subject is the
`reason`, the trailers `Changeset-Id`, `Reason`, `Agent`, `Behesid-Validation`, one `Source` per
entry of the changeset's `sources`, and `Agent-Session`/`LLM-Model` when known. `agent`,
`session` and `llm_model` set those (else `BEHESID_AGENT`, `BEHESID_AGENT_SESSION`,
`BEHESID_LLM_MODEL`; `agent` then defaults to your MCP client's name, on the CLI to
`human:<git user.name>`). `commit` reports it: `committed`, `sha`, `changeset_id`, `message`,
and a `note` saying why nothing was committed (no git work tree, git missing, git refused). `workspace_id` works in that workspace instead (see `workspace`).

## rename

Renames `element` to `to`: every reference the parser finds, flow ends, the file name, and
`renamed_from`. Labels, docs and longer names are untouched. `dry_run: true` writes nothing.
Same output and commit as `apply` (`agent`, `session`, `llm_model`). `workspace_id` works in that workspace instead (see `workspace`).

## fix-refs

Respells references to names that are no longer elements through the element whose
`renamed_from` lists them. A name listed by more than one element is refused with the
candidates. `dry_run: true` writes nothing. Same output and commit as `apply` (`agent`,
`session`, `llm_model`). `workspace_id` works in that workspace instead (see `workspace`).

## workspace

Per-task git worktrees (the model directory must be in a git work tree). `action: open` makes
branch `ws/<id>` and the worktree `<store_dir>/wt/<id>` from the newest `baseline/vN` tag (from
`HEAD`, with a note, before the first baseline); `name` is the id (a lowercase slug, at most 40
characters; default `ws-` and 12 hex digits). When the model directory is already in a linked
worktree, that worktree is the workspace. `action: list` shows every workspace with its `head`,
`base`, `stale`, uncommitted `changed` paths and lease. `action: close` with `workspace_id`
removes a worktree behesid made, refusing while it has uncommitted changes; the branch stays
unless `delete_branch: true`. `action: refresh` rebases the workspace onto the newest baseline,
or aborts on a conflict and reports the paths (a conflict error; nothing changes). The store
keeps itself out of git (it writes its own `.gitignore`); a worktree whose directory was
deleted is no workspace (`git worktree prune`).

Pass the id as `workspace_id` to every model verb to work there. The first write takes the
workspace's lease for your `session` (else your `agent`; over MCP your session is the MCP
session) for 30 minutes from your last write; a write from another session meanwhile is a
conflict naming the holder. Inside a workspace's worktree every write is that workspace's,
named or not. A write to a stale workspace (a newer baseline exists) succeeds with a warning.

## diff

The semantic diff between `base` (a branch, tag or commit) and `head` (another ref; by default
the working tree of the model directory, or of the workspace `workspace_id` names): objects
added, removed, changed field by field and renamed, with equation references and a text diff,
and `loops`: the feedback loops `added`, `removed` and `repolarised` (each side searched with
`loops`' default bounds; `truncated` when a search stopped at them). A loop through a renamed
element reads as one removed and one added. Nothing is checked out.

## review

The pre-merge report of the workspace `workspace_id`, for a human: its last commit against its
base (the newest `baseline/vN`, or before the first baseline the commit it shares with the main
worktree). It holds the semantic diff, the loop changes, provenance coverage (the share of
added, changed and renamed elements with both `provenance` and `references`), the risk `tier`
(`low`: only docs, labels, tags and citations; `medium`: constant values, lookup points or an
element's units too; `high`: anything else — the model's time or units, any loop change —
included), the head's full validation, and a before/after default run
(no overrides, the model's method, `default_budget_s`) with its divergences ranked as `compare`
ranks them. Commits whose `Agent` is yours (`agent`; `session` matches `Agent-Session`) are
marked self-authored. It writes `review.md` and `review.html` to `<store_dir>/reviews/<id>/`
and returns their paths, `review_hash` and each workspace's `tag_command`: the exact
`git tag -s baseline/vN` a human runs on the merge commit after merging the branch with
`--no-ff` (none while the head has validation errors: that baseline would not verify). You
never run it. A stale workspace is not reviewed: `ok: false`, `stale: true`
(exit 13); refresh it first. A workspace not reviewed yet is refused (a conflict) while
`max_open_reviews` (5) open workspaces have reviews. `all_low: true` reviews every open
workspace whose changes are all low-tier and whose head validates into one report, without
runs and without tag commands (each merge changes the next one's hashes; tag each from its
own review); workspaces it cannot review are named in `notes`.

## hook

`action: install` writes two git hooks (into the directory git uses; `core.hooksPath`
honoured): `commit-msg` refuses a commit that touches a model file without the trailers
`Changeset-Id`, `Reason`, `Agent` and `Behesid-Validation`, and `pre-commit` refuses staged
model files that are not in canonical form, as the index holds them. A commit that touches no
model file passes untouched; behesid's own commits pass; `--amend` keeps HEAD's model files,
so it needs the trailers too (only `git commit --no-verify` skips the hooks, and `review`
then shows the commit without an `Agent`). A `git merge` commit passes `commit-msg`: its
merged commits carry the trailers (a `--squash` commit does not). A hook that is not behesid's
is never replaced (a conflict) unless `force: true`; `action: uninstall` removes behesid's hooks
only.
`action: check-msg` (with `file`, the message file) and `action: check-staged` are what the
hooks run; they are hook-internal, and you do not call them.

## verify-baseline

Checks the `baseline/vN` tag `tag` and reports each check: `name` (the tag object carries this
name, so an old signed tag copied to a newer name fails), `signature` (git's `verify-tag`, GPG
or SSH as git is configured; a lightweight tag has none), `trailers` (the message carries `Model-Hash`, `Validation-Hash`,
`Review-Hash` and `Rationale`), `model-hash` and `validation-hash` (recomputed from the model
at the tagged commit, the validation at `level: full`) and `valid` (that validation finds no
error). `ok` is false when any check fails (exit 10). Load a model only from a tag this
verifies. Read-only; it never checks anything out.

## language

The equation grammar and operator precedence, every builtin with its signature, unit rules,
example and doc, the file schema ids, and the check rules with their severity and fix. Read it
before writing equations.

## run

Simulates the model: `set` overrides constants (`"name=value"`, `"name[e1,e2]=value"`),
`method` is `euler` or `rk4`, `outputs` picks elements (default: stocks, flows and auxes),
`budget_s` bounds the time loop. Returns `run_id`, per-output summaries (start, end, min, max, mean),
findings and `run_dir`; over MCP the run's files also come as resource links. A repeated request
is `cached`. `workspace_id` works in that workspace instead (see `workspace`).

`runs` above 1, or any `sample`, runs an ensemble: `sample` draws constants per run
(`"name=normal(mean, sd)"`, `lognormal(mean, sd)`, `uniform(min, max)`,
`triangular(min, mode, max)`; a constant with dims and no subscript draws each element),
`sampling` is `lhs` (Latin hypercube, the default) or `random`, and `seed` (default 0) fixes the
draws, including those of random builtins (NORMAL, UNIFORM, ... in equations), so the same request
gives the same numbers. An ensemble stores the mean, sd, min, max and p10/p50/p90 of each output
over the runs at every saved time; its summaries add the end value's `end_p10`, `end_p50`,
`end_p90`, and `ensemble` reports the runs, seed and samples. Its outputs must fit in `max_mem`
(`BEHESID_MAX_MEM`, default 2GiB), or the request is refused with the bytes it needs.

## series

One element's lines from a stored run: `run_id`, `element`, an optional window `from_time` and
`to_time` (a time value, or a calendar date when the model has one), at most `max_points`
points per line (default 120; above that min/max downsampled, `downsampled: true`).
For an ensemble run `stat` picks the statistic over its runs (`mean`, `sd`, `min`, `max`, `p10`,
`p50` — the default — or `p90`); a single run takes none. CLI: `--from-time`, `--to-time`.

## runs

The stored runs, newest first, at most `limit` (default 20): `run_id`, when it was stored, its
size, `ok`, the model id and hash, method, backend, behesid version, timings and
`ensemble_runs` (an ensemble's number of runs; null for a single run). Calibrations and
sensitivity analyses are not runs: they are kept apart, under their own ids.

## compare

Compares stored runs with the first of `runs` (2 to 20 run ids, sharing a time grid). For each
output both saved, each line's relative difference `|b - a| / max(|a|, |b|)` is taken at every
saved time; a line that differs reports its values and `delta` at the `start`, the `end` and the
time of its `largest` difference, that largest difference `rel` (`null` when infinite: one side
not finite), and `first_divergence`, the first time `rel` exceeds `rtol` (default 1e-6). Lines
are ranked by `rel`; `identical` counts the lines that never differ, `diverged` those past `rtol`.
Outputs saved with other dimensions are listed in `reshaped`, not compared. An ensemble run is
compared through its median (`p50`) over its runs.

## calibrate

Fits constants to data and proposes them; it never changes the model. `params` names what to
fit: `"name"` within the constant's `range`, or `"name=[low, high]"` (a constant with dims fits
each element; `"name[e1,e2]=[low, high]"` one). `prior` adds `"name=normal(mean, sd)"`.
`targets` gives the data: `"output=run:<run_id>"` (a stored run's values; an ensemble's p50;
every cell of an array output unless one is named) or `"output=<file.csv>"` (columns `time` and
`value`, in any order, each time once; a time is a number or, with a calendar, a date; one
cell: `"output[e1,e2]=..."`).
Points outside the model's time or the `from_time`/`to_time` window, and empty values, are
left out. Residuals are divided by the data's sd, so targets in other units add up; `weights`
(`"target=2"`) multiplies one. `loss` is `wsse` (default) or `huber` (robust to outliers).
`optimizer` `auto` takes `lbfgsb` (gradient search from the current values) on the jax backend,
with exact gradients, and `de` (differential evolution, then `lbfgsb`) on numpy; `max_iter`
bounds each, `seed` fixes both and random builtins. Returns `estimates` (value, start, bounds,
`se` and a 95 % interval — null when the data cannot pin an entry down —, `at_bound`), per
target `points`, `mse`, `mape`, `r2`, the Theil shares `theil_um` (bias), `theil_us` (spread)
and `theil_uc` (unsystematic) and the residuals' lag-1 `autocorr`, `converged` and
`gradient` (`exact` or `differences`). `ops` (also
`ops_file`) is a changeset setting the fitted values, guarded by `expect_hash`: review it, add
`sources`, and pass it to `apply`. `set`, `method` and `budget_s` are as in `run`; over budget,
`best` holds the best values so far and nothing is stored. Stored as `calibration_id`
(`cal_...`) with `fit.csv` (data against model at each point); a repeated request is `cached`.
`workspace_id` calibrates that workspace's model.

## sensitivity

Ranks constants by their influence on outputs. `vary` takes `"name=dist(a, b)"` as `run`'s
`sample` does (`uniform(min, max)` for a plain range); without it every constant with a `range`
varies over it, except those `set` holds. `design` is `oat` (each constant alone from its low to its high: the ends of a
uniform or triangular, the 5th and 95th percentiles of a normal or lognormal; 2k + 1 runs),
`morris` (the default: elementary effects over `samples` trajectories, default 10; k + 1 runs
each) or `sobol` (first and total order indices; `samples` a power of two from 16, default
256; `samples` (k + 2) runs). Each cell of each of `outputs` (default: every stock) is a metric: its
`end` value (the default) or its `mean`, `min` or `max` over the saved times (`metric`). Per
metric, `influences` ranks the varied entries by `score` — oat `|y_high - y_low|`, morris
`mu_star`, sobol `total` — with each design's detail; a score is null when a run was not finite.
Every run draws the same random-builtin numbers (from `seed`), so noise does not pass for
influence. `set` fixes other constants, `method` and `budget_s` are as in `run`. The analysis is
stored as `analysis_id` (`sens_...`) with `table.csv`, every ranking as a table; a repeated
request is `cached`. A design needing more than 100,000 runs, or memory beyond `max_mem`, is
refused. `workspace_id` analyses that workspace's model.

## dominance

Which feedback loops drive each stock, and when (Loops That Matter). One run at the model's
values (`set`, `method`, `seed` and `budget_s` as in `run`) is re-evaluated at every step: a
link's score is the share of the change in its target's equation that the source alone caused,
signed by the link's direction of effect; a loop's score is the product of its link scores,
per element of every dim its elements have (`level`): a loop through a `SUM` is one loop per
summed element, the sum's score shared out by each element's change. An outflow a
non-negative stock caps is scored by its equation, before the cap; the cap is not scored. `loops`
lists every loop found, as `elements` and as the `nodes` scored (a delay or smooth through its
hidden stocks `__<element>__d<k>`; a loop of one hidden stock is the call's own draining loop),
with `polarity` (`positive`, `negative` or `mixed` over the run) and `peak`; a loop through a
`DELAY_FIXED` is `unscored`. For each stock cell of `stocks` (default: every stock), `periods`
give the dominant loop over time — the one with the largest share of the stock's loop scores
— with its mean `share`, and `loops` ranks the loops through it by mean share; `shifts` lists
each change of dominant loop. `max_length` (nodes, hidden stocks included) and `limit` bound
the loop search as in `loops` (`truncated_by`). Stored as `analysis_id` (`dom_...`) with
`loops.csv` (every loop's scores) and `relative.csv` (every stock cell's shares); a repeated
request is `cached`. A run whose steps do not fit in `max_mem` is refused. `workspace_id`
analyses that workspace's model.

## convert

Writes files, so it counts as mutating. Imports XMILE (`.xmile`, `.stmx`, `.itmx`, `.xml`) or Vensim `.mdl` from `input` as a changeset — in the
output, written to `out`, or built straight into the new or empty directory `to_dir` — with
import findings and the source-name-to-id map `names`. Exports the model with `to: xmile` and
`out`. Neither `out` nor `to_dir` may lie inside the model directory (`to_dir` may be a new
or empty model directory itself). `workspace_id` works in that workspace instead (see `workspace`).

## scenario-schema

The model's scenario surface, for an application that lets a small model ask "what if": the
`catalogue` (levers with their units, `bounds`, `dims` and profiles; outputs with their
aggregations and thresholds; scenarios; the model's time `form`, `first`, `last` and `grains`;
the narrative `languages`), labels and synonyms in `language`; `selection`, the JSON Schema of
step one (choose lever and output ids); and `request_schema`, the JSON Schema of a request —
every id and dimension element an enum, bounds as minimum and maximum, one variant per lever
and profile with exactly the fields it needs — narrowed to `levers` and `outputs` when given
(step two; an empty `levers`, over MCP, offers no lever — on the CLI `--levers` names at least
one). Unnarrowed, a question may use only the dims every output has. The schema accepts
nothing the model cannot answer, and is stricter where that helps a small model (every lever
setting names its profile; values are numbers in the lever's units); `scenario-validate`
checks the rest (overlaps, a window's order, two grains, a threshold every user names). A model that does
not pass quick validation answers with its `findings` (exit 10). Concise drops doc text. `workspace_id`
reads that workspace's model.

## scenario-validate

Checks a scenario request (spec §10.3) — the question an end user's application asks: an
optional `base` scenario, a `horizon`, lever settings (`id`, `at`, `profile` `constant`, `step`,
`window` or `ramp`, `from`, `to`, `value`, optionally in other `units`), `uncertainty`
(`none`, or `scenario` with `runs` and `seed`), `language` and the `question` (`outputs`,
`filter`, `by` a time grain and dims, `aggregate`, `threshold`, `compare_to_base`). Give it as
`request` (an object), as JSON `text`, in `file`, or on stdin (CLI). `at` and `filter` name an
element, a subrange, a list of them, or `"*"` for every element. A valid request comes back
normalised:
every default filled in, elements listed in declaration order with subranges expanded (a
dimension whose every element is named is left out, which means the same), values in the
lever's units. Otherwise `ok` is false and `hints` say what to change, each with `path`,
`code`, `message` and, when known, `allowed` and `did_you_mean`. A model that does not pass
quick validation answers with its `findings` instead. Exit 10 when not ok (hints or findings). `workspace_id`
checks against that workspace's model.

## health

Whether behesid can serve: `status` (`ok` or `degraded`), version, the model directory and
whether it exists, whether runs can be stored, the backend, and the `problems` behind a
degraded status.

## skill

This text: the workflow, the rules and one section per verb.
