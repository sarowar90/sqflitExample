# Review bot eval harness

Tests that say what correct bot behaviour is, so "the bot is good" stops being a
matter of opinion.

```bash
# the deterministic tests — fast, no network, no model
python -m unittest discover -s tools/review_bot_eval/tests -t tools/review_bot_eval

# what fixtures exist and why
python tools/review_bot_eval/run_eval.py --list

# grade a run
python tools/review_bot_eval/run_eval.py sql_injection_search --report runs/*.md
```

Standard library only. No pip install, no pytest, no PyYAML.

## Two layers, because the bot has two kinds of failure

**The deterministic layer** (`review_eval/`, 30 tests) is the parser and the
scorer. No model runs. It answers: given this output, did the bot pass? Every
parser test encodes drift a real checker actually produced — dropped brackets,
`### Insufficient context` at finding depth, a heading with no line number.
None of it is hypothetical, and none of it is defensive guessing.

That matters because a scorer that trips on a missing bracket reports a bot
failure that is really a parser failure. That is the most expensive wrong
answer available here: it sends you to fix an agent that was right.

**The behavioural layer** (`fixtures/`) is a patch plus an expectations file.
Running it costs a model. It answers: on this diff, does the bot find the bug
and stay quiet about everything else?

## must_flag and must_not_flag

```jsonc
"must_flag":     [{ "id": "...", "file": "...", "min_severity": "blocking",
                    "keywords_all": ["transaction"] }],
"must_not_flag": [{ "id": "dashboard-dead-code", "keywords_all": ["_buildEmptyState"] }],
"max_findings":  6
```

A fixture passes only if it catches everything in `must_flag`, says nothing
matching `must_not_flag`, and stays under `max_findings`.

**The second list is the one that keeps the bot useful.** Satisfying `must_flag`
alone is trivial — comment on everything and you catch every bug. That bot gets
muted in a week, and a muted bot catches nothing. `must_not_flag` is
`REVIEW_POLICY.md` §5 with teeth.

`min_severity` matters for the same reason in reverse: reporting sale atomicity
as a Consider is not catching it.

## Fixtures

| Fixture | Tests |
|---|---|
| `cart_checkout_atomicity` | The diff that got merged into `main` by accident. `flutter analyze` clean, 24 tests green, and it broke sale atomicity anyway. If the bot cannot catch this, nothing here has a point. |
| `sql_injection_search` | The direction that had never been tested: `security-scanner` **firing**. It had only ever returned "no findings", so its silence was verified and its catching was not. An agent written mostly to stay quiet passes a silence-only suite by staying quiet. |

Fixtures are patches, not branches. The cart-checkout fixture was originally a
branch, and it got merged into `main` — because a branch invites merging. A
patch does not.

## Why the runner is recorded, not live

Driving the pipeline end to end needs the `claude` CLI on `PATH`, which the
machine this was built on does not have. Writing a live runner that had never
been run once — to test a bot — would be exactly the thing this harness exists
to prevent.

So the loop is manual where it has to be and deterministic where it counts: run
the pipeline however you run it, save each checker's markdown into `runs/`, and
grade it here. `--apply-to` puts a fixture in a scratch worktree so the pipeline
has a real diff to read.

When the CLI is available, `cmd_apply` is the seam a `--live` mode plugs into.

## Result of the last run

`sql_injection_search` — PASS. 1/1 caught, 1 finding, no noise. The
`security-scanner` returned Blocking with the full path from the inventory
search box to `rawQuery`, having previously never fired at all.
