# PR Review Bot — Submission

A multi-agent PR review bot for [sarowar90/sqflitExample](https://github.com/sarowar90/sqflitExample),
an offline Flutter POS app. Built on Claude Code subagents, wired to GitHub Actions.

## The short version

Partway through building this, a PR was merged into `main` that added a cart checkout with
`flutter analyze` clean and all 24 tests passing. It also recorded sales without decrementing stock
atomically, and left the inventory screen showing stock that had already been sold. Every automated
gate the repo had said yes.

That PR is now [a test fixture](tools/review_bot_eval/fixtures/cart_checkout_atomicity.patch), and
the bot catches it. **Green is not proof** is the thesis, and the repo proved it by accident.

---

## (a) Review logic — [`REVIEW_POLICY.md`](REVIEW_POLICY.md)

What gets flagged, grounded in this app's real invariants rather than a generic checklist.

| Section | Owns |
|---|---|
| §1 Correctness | Sale atomicity, state/DB drift, the `product_name` snapshot, schema and migrations, Riverpod usage |
| §2 Tests | Untested writes, missing regression tests, miswired tests |
| §3 Security | SQL interpolation, new network calls, unguarded destructive paths, new permissions |
| §4 Style | Only what `flutter analyze` cannot see |
| **§5 Known noise** | **What the bot must stay silent about** |

§5 is the one that keeps the bot useful. A review is useful when every comment would change what a
maintainer does; noise is the default failure mode, and a muted bot catches nothing. So the
documented dead code, the `greeting.dart` leftovers, and the `mobile_scanner` Kotlin warning are
listed as things not to report.

The security section states the threat model first — offline, on-device, single-user, no auth, no
backend — because without it a reviewer files "no authentication on the delete path" on every PR.
That comment is wrong here, wrong the same way every time, and two of them is all it takes.

## (b) Subagent architecture — [`REVIEW_BOT.md`](REVIEW_BOT.md)

```
PR → Orchestrator
      ├─ pr-context-explorer ──→ context bundle (facts only, no judgement)
      ├─ Plan ────────────────→ which checkers run, severity budget
      ├─ invariant-checker  ─┐
      ├─ test-auditor       ─┤ parallel, same bundle, one policy
      ├─ security-scanner   ─┤ section each
      ├─ style-checker      ─┘
      ├─ synthesis (orchestrator) → dedupe, normalise, enforce budget
      └─ verifier → re-reads code WITHOUT the bundle → survivors post
```

The design is shaped by one constraint: **subagents start cold.** They share no context and report
only to the orchestrator. Left alone, four checkers each re-read the repo and arrive at four
slightly different understandings — worse than the cost. So Explore gathers context once and the
orchestrator relays the same bundle to all four.

The split follows the policy's own sections, so each rubric has exactly one owner and no two agents
can file the same problem. The verifier works *without* the bundle on purpose: the bundle is what
made the checkers confident, so re-using its framing would reproduce its mistakes.

Agents: [`.claude/agents/`](.claude/agents/)

## (c) Context management — [`REVIEW_BOT.md#context-management`](REVIEW_BOT.md)

The budget is room in the orchestrator's window. The rule: **the orchestrator never holds a file** —
it holds a bundle, four reports, and a verdict.

One measured run:

| Stage | Tokens | Tool calls | Returned |
|---|---:|---:|---|
| `pr-context-explorer` | 54,801 | 21 | ~200-line bundle |
| `invariant-checker` | 33,343 | 4 | 2 findings |
| `test-auditor` | 41,018 | 2 | 1 finding |
| `security-scanner` | 35,715 | 2 | 1 line |
| `style-checker` | 35,504 | 2 | 1 line |
| **Total** | **200,381** | **31** | **~320 lines** |

**~200k tokens of work; ~320 lines reached the orchestrator.** The other ~99% died with the windows
that spent it.

The checkers' 2–4 tool calls each are the second thing in that table: they are not exploring. That
is the "open only files the bundle names" instruction holding, and it is measured, not hoped for.

Paid twice, stated openly: the bundle is relayed to four checkers, so **every line Explore writes is
bought five times.** That makes the 400-line cap arithmetic, not tidiness. Compaction is a fallback,
not a strategy — it is undirected and cannot know the load-bearing list outranks a quoted hunk.

## (d) TDD tests — [`tools/review_bot_eval/`](tools/review_bot_eval/)

```bash
python -m unittest discover -s tools/review_bot_eval/tests -t tools/review_bot_eval   # 30 tests
python tools/review_bot_eval/run_eval.py --list
```

Two layers:

**Deterministic** (30 tests, stdlib only, no model). The findings parser and scorer. Every parser
case encodes drift a checker really produced — dropped brackets, `### Insufficient context` at
finding depth, a heading with no line number. None invented. A scorer that trips on a missing
bracket reports a bot failure that is really a parser failure, which sends you to fix an agent that
was right.

**Behavioural** (fixtures). A patch plus expectations:

```jsonc
"must_flag":     [{ "id": "sell-cart-not-atomic", "file": "lib/database_helper.dart",
                    "min_severity": "blocking", "keywords_all": ["transaction"] }],
"must_not_flag": [{ "id": "dashboard-dead-code", "keywords_all": ["_buildEmptyState"] }],
"max_findings":  6
```

`must_not_flag` matters as much as `must_flag`. Satisfying `must_flag` alone is trivial — comment on
everything and you catch every bug. That is §5 with teeth.

| Fixture | Tests | Result |
|---|---|---|
| `cart_checkout_atomicity` | The diff that got merged by accident. Analyze clean, 24 tests green, sale atomicity broken anyway. | Findings reproduced by the checkers; scored via the harness |
| `sql_injection_search` | `security-scanner` **firing** — it had only ever returned "no findings", so its silence was verified and its catching was not | **PASS** — 1/1 caught, no noise. Blocking, with the full path from the search box to `rawQuery` |

Also 35 Flutter tests: `flutter test`.

## (e) Refactoring notes — [`refactor/dashboard-metrics-provider`](https://github.com/sarowar90/sqflitExample/tree/refactor/dashboard-metrics-provider)

`DashboardScreen.build()` computed the four dashboard numbers inline — business rules where no test
could reach them, and the app's one piece of derived state living outside `providers.dart` where
every other piece lives.

The real find was not the dead code. It was the low-stock threshold: a bare `<= 5`, written out
**three times** — dashboard, inventory list, product detail. Three copies of one rule is the
maintainability problem; the dead code was only the visible one. Now `kLowStockThreshold`, in one
place.

**Characterization tests came first**, pinning the metrics as the widget computed them — including
that five is low and six is not — so the extraction had something to be wrong against. They passed
unchanged afterwards. That is the only evidence behaviour held.

Also removed what `CLAUDE.md` already listed as safe to delete: the commented-out recent-sales list
and its two orphaned builders, the `greeting.dart` practice files.

| | Before | After |
|---|---|---|
| `flutter analyze` | 2 warnings | **0** |
| `flutter test` | 24 | **35** |
| Copies of the low-stock rule | 3 | **1** |

## (f) GitHub Actions — [`.github/workflows/`](.github/workflows/)

| Workflow | Trigger | Automatic? |
|---|---|---|
| [`pr-review.yml`](.github/workflows/pr-review.yml) | `pull_request` | Yes — writes one comment |
| [`issue-triage.yml`](.github/workflows/issue-triage.yml) | `issues: opened` | Yes — writes labels |
| [`auto-fix.yml`](.github/workflows/auto-fix.yml) | A human adds `bot:autofix` | **No** |

Safety, drawn by blast radius rather than confidence:

- **`pull_request`, not `pull_request_target`.** The latter runs with secrets against code the PR
  author controls — on a public repo, handing `ANTHROPIC_API_KEY` to a stranger's branch. Fork PRs
  get an explicit skip.
- **Least privilege:** `contents: read`, `pull-requests: write`. Nothing else.
- **Author-controlled text** (PR titles, issue bodies) reaches the model through env vars, never the
  shell. A title like `"; rm -rf / #` stays a string.
- **The bot never pushes to the branch under review, never merges, and never turns CI green or red.**
  The `checks` job is the gate and waits on no model; the review is advice beside it.
- **Auto-fix is verified against itself** — after the model reports success the workflow re-runs
  `analyze` and `test` independently, because the model's claim to be green is not evidence.
- **`concurrency`** cancels superseded runs. One measured review is ~200k tokens; a force-push should
  not pay twice.

## (g) Live PR, auto-fix and triage results — **not done**

This is the gap, and I would rather name it than dress it up.

The workflows have never run. Three things are missing, and all three need a human:

1. **`gh auth login`** — needs a browser. Every PR in this repo so far was opened by hand through a
   `pull/new/` link.
2. **`ANTHROPIC_API_KEY` as a repo secret** — `gh secret set ANTHROPIC_API_KEY --repo sarowar90/sqflitExample`.
3. **Screenshots** — I cannot take them, and generating pictures of a bot comment that never appeared
   would be fabricating the evidence this whole submission argues against.

So the honest status: **the pipeline is verified, the plumbing is not.** The agents have been run
end to end against real diffs and their output scored by the harness — that is (d), and it is real.
What has not happened is those same agents running inside Actions, on a live PR, posting a comment.
The YAML parses. Nothing more is claimed.

To finish it: set the secret, then open a PR — the `refactor/dashboard-metrics-provider` branch is a
good first one, or apply `tools/review_bot_eval/fixtures/cart_checkout_atomicity.patch` to a branch
to watch the bot catch the bug that got merged for real.

---

## What I would fix first

**Plan and the verifier are designed but not built.** The four checkers and Explore exist and run.
Plan's authority to skip work is load-bearing in the design — six agents on a two-line diff is
theatre — and the verifier is the whole anti-noise bet. Both are currently the orchestrator prompt
doing it inline.

**`must_flag` matching is keyword-based.** It discriminates a test-coverage finding from a
correctness one via the word `untested`, which couples the expectations to the output template.
Tagging findings by originating checker would be cleaner.

**Severity calibration is unsettled.** `test-auditor` returned Blocking for an untested `sellCart`,
reasoning from the "a rename must not walk around the rule" instruction. Defensible, but the policy
only says Blocking for `sellProduct` by name. Either the policy should generalise or the agent
should relax — right now it is the agent's judgement filling a gap.
