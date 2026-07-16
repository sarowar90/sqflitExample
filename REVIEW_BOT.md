# Review Bot Architecture

How the work of reviewing a PR is split across subagents, and why each one exists.

[`REVIEW_POLICY.md`](REVIEW_POLICY.md) defines *what* to check. This file defines *who* checks it.
The two are deliberately separate: the policy changes as the app grows, the pipeline should not.

## The constraint that shapes everything

Claude Code subagents **start cold**. Each one gets a fresh context window, cannot see what another
subagent found, and returns a report only to the orchestrator. Nothing is shared implicitly.

This has two consequences the design has to answer for:

1. **Re-derivation is the default failure.** Point four checkers at a PR with no preparation and
   each one independently reads the diff, opens `database_helper.dart`, and works out what the app
   does. Four times the tokens for one repo's worth of understanding — and four subtly different
   understandings, which is worse than the cost.
2. **The orchestrator is the only bus.** Explore's findings reach the checkers only because the
   orchestrator copies them into each checker's prompt. There is no shared memory to lean on.

So: gather context **once**, package it, hand the same package to every checker.

## Pipeline

```mermaid
flowchart TD
    T[PR opened] --> O[Orchestrator]
    O --> E[Explore subagent]
    E -->|context bundle| O
    O --> P[Plan subagent]
    P -->|review plan: which checks run| O
    O --> C1[invariant-checker]
    O --> C2[test-auditor]
    O --> C3[security-scanner]
    O --> C4[style-checker]
    C1 --> S[Orchestrator: synthesis]
    C2 --> S
    C3 --> S
    C4 --> S
    S --> V[verifier subagent]
    V -->|survivors only| S
    S --> R[Post review via gh]
```

Stages 3 and 4 fan out in parallel; everything else is sequential.

---

## The subagents

### 1. Explore — gather context

**Exists because:** the four checkers would otherwise each re-read the repo from scratch. This is
the single biggest cost saving in the design, and the main source of consistency: every checker
reasons about the same facts.

**Reads:** the PR diff, every changed file in full, the tests covering those files, and the
neighbours the changed code actually touches (a diff in `providers.dart` pulls in
`database_helper.dart`, because the golden rule spans both).

**Returns a context bundle:** changed files with their diff hunks, the surrounding definitions,
which policy sections the changed paths map to, and which invariants the touched code is
load-bearing for. Facts only — no judgement. The moment Explore starts saying "this looks wrong"
it is doing the checkers' job with none of their focus.

**Why the built-in `Explore` type:** it is read-only. A context-gathering step must not be able to
edit the branch it is reading.

### 2. Plan — decide what to review

**Exists because:** not every PR needs every check. A README typo does not need the security
scanner, and running it anyway is how you train yourself to skim the bot's output. Plan reads the
bundle and returns which checkers to run, on which files, against which policy sections.

It is also where the **severity budget** lives: a 12-line bugfix that produces nine "Consider"
comments has failed, regardless of whether the nine are individually correct. Plan caps the
expected finding count so the fan-out cannot flood a small diff.

**Why a subagent and not a hardcoded rule:** file-extension routing (`*.md` → style only) breaks
immediately. A change to `docs/state-management.md` that rewrites the golden rule is a correctness
concern in a Markdown file. Deciding what a diff *means* needs a model.

**Cheapest place to skip work:** Plan is allowed to return "no checks" and end the run.

### 3. The checkers — focused, parallel, one rubric each

Four custom subagents, each owning one section of the policy. All four get the same context bundle
in their prompt.

| Subagent | Owns | Why it is its own agent |
|---|---|---|
| `invariant-checker` | Policy §1 Correctness | The only checker that can produce Blocking findings about money and stock. Given a shared window it would spend attention on style and under-weight sale atomicity. It gets its own so it cannot be distracted. |
| `test-auditor` | Policy §2 Tests | Asks one question — does this change need a test that is not here — and answers it against the suite. Wants deep test knowledge, not app knowledge. |
| `security-scanner` | Policy §3 Security | The narrowest rubric: SQL interpolation, new network calls, unguarded destructive paths, new permissions. Kept separate mostly to keep the threat model *small*. A general reviewer talks itself into web-app findings that do not apply to an offline on-device app. |
| `style-checker` | Policy §4 Style | Deliberately thin — `flutter analyze` already runs in CI. It only sees what the linter cannot: theme tokens, SQL escaping `DatabaseHelper`, PR title format. Exists to be skippable. |

**Why split at all**, given four agents cost more than one: separation buys focus and independence.
Each checker's noise stays in its own window instead of polluting the others' reasoning, and one
checker having a bad run does not corrupt the rest. The parallel fan-out also means wall-clock is
the slowest checker, not the sum.

**Why these four and not more:** the split follows the policy's sections, so there is exactly one
owner per rubric and no negotiation about who reports what. More agents would mean overlapping
rubrics, which means duplicate comments, which the policy forbids.

### 4. Synthesis — the orchestrator's own job

Not a subagent. The orchestrator holds every checker's report and:

- **Deduplicates.** Overlap is designed in: a `where: 'name = $name'` is both a Blocking security
  finding and a correctness bug. The policy says one comment per problem, so someone has to merge
  them. Only the orchestrator sees all four reports.
- **Normalizes severity.** Four agents rate independently; "Should fix" from the test auditor and
  from the security scanner must mean the same thing to the reader.
- **Enforces the budget** Plan set, dropping the weakest findings if the diff is small.
- **Relays.** Subagent reports are not shown to the user. Whatever the orchestrator does not say
  out loud, nobody reads.

### 5. Verifier — the anti-noise pass

**Exists because false positives are what get a bot muted**, and a muted bot catches nothing. This
is the whole bet of the design.

Takes the deduplicated findings and re-reads the actual code with fresh eyes, without the context
bundle. For each finding it asks: does the described failure really happen, on these lines, as
written? Findings that survive get posted; findings that do not get dropped silently.

**Why cold context is the point here:** the bundle is what made the checkers confident. Handing the
verifier the same framing would reproduce the same mistake. It must be able to say "the code does
not say what you think it says."

Runs once over all findings rather than per-checker — it needs to see the merged set to catch a
finding that only looks right in isolation.

---

## Tradeoffs, stated plainly

- **This is more machinery than a small PR deserves.** Six agents on a two-line fix is theatre.
  Plan's authority to skip checkers, and to end the run outright, is what keeps that honest — it is
  a load-bearing part of the design, not an optimization.
- **Cold starts cost tokens.** The context bundle amortizes the reading, but each subagent still
  pays to boot. Accepted, in exchange for focus and parallelism.
- **The bundle is a single point of failure.** If Explore misses a file, four checkers are
  confidently blind in the same way. Mitigated by the verifier working without the bundle — it is
  the one stage that can notice the gap.
- **Nondeterminism.** Independent agents disagree on severity across runs. Synthesis normalizes,
  but the review will not be byte-identical between runs on the same PR.

## What runs where

The subagent definitions live in `.claude/agents/*.md`. The orchestrator is a Claude Code session
triggered on `pull_request`, posting through `gh pr comment`.
