#!/usr/bin/env python3
"""Score a review bot run against a fixture's expectations.

    # grade saved checker reports
    python run_eval.py cart_checkout_atomicity --report runs/*.md

    # apply a fixture to a scratch worktree so you can run the pipeline on it
    python run_eval.py sql_injection_search --apply-to ../../.eval-tree

    python run_eval.py --list

Recorded, not live. Driving the pipeline end to end needs the `claude` CLI on
PATH, which this machine does not have; wiring that in without being able to
run it once would be writing an untested runner to test a bot. So the loop is:
run the pipeline (however you run it), save each checker's markdown, grade it
here. The grading is the part that has to be deterministic, and it is.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from review_eval.parser import parse_reports
from review_eval.scorer import score_fixture

FIXTURES = Path(__file__).resolve().parent / "fixtures"


def load(name: str) -> dict:
    path = FIXTURES / f"{name}.expected.json"
    if not path.exists():
        sys.exit(f"no such fixture: {name}\navailable: {', '.join(sorted(names()))}")
    return json.loads(path.read_text(encoding="utf-8"))


def names() -> list[str]:
    return [p.name.removesuffix(".expected.json") for p in FIXTURES.glob("*.expected.json")]


def cmd_list() -> int:
    for name in sorted(names()):
        spec = load(name)
        print(f"{name}")
        print(f"  patch       {spec['patch']}")
        print(f"  must flag   {len(spec['must_flag'])}")
        print(f"  must ignore {len(spec['must_not_flag'])}")
        for line in spec.get("why", []):
            print(f"  | {line}")
        print()
    return 0


def cmd_apply(name: str, target: Path) -> int:
    """Put the fixture in a worktree so the pipeline has a real diff to read."""
    spec = load(name)
    patch = FIXTURES / spec["patch"]
    if not target.exists():
        subprocess.run(["git", "worktree", "add", "-b", f"eval/{name}", str(target)], check=True)
    result = subprocess.run(["git", "apply", str(patch)], cwd=target)
    if result.returncode:
        return result.returncode
    print(f"applied {spec['patch']} to {target}")
    print(f"PR title for the run: {spec['pr_title']}")
    print("\nnow run the pipeline against that tree and save each checker's markdown, then:")
    print(f"  python run_eval.py {name} --report <files...>")
    return 0


def cmd_score(name: str, reports: list[Path]) -> int:
    spec = load(name)
    texts = [p.read_text(encoding="utf-8") for p in reports]
    findings = parse_reports(texts)
    result = score_fixture(findings, spec, fixture=name)

    print(result.summary)
    print()
    for m in result.matched:
        print(f"  caught   {m['id']:<38} at {m['at']}")
    for m in result.missed:
        print(f"  MISSED   {m['id']:<38} {m.get('what', '')}")
    for n in result.noise:
        print(f"  NOISE    {n['id']:<38} {n.get('what', '')}")
    if result.over_budget is not None:
        print(f"  BUDGET   {result.findings_count} findings, cap is {result.over_budget}")

    if findings:
        print(f"\n  parsed {len(findings)} finding(s):")
        for f in findings:
            where = f"{f.file}:{f.line}" if f.line else f.file
            print(f"    [{f.severity.name.lower().replace('_', ' ')}] {where}")

    return 0 if result.passed else 1


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("fixture", nargs="?", help="fixture name (see --list)")
    ap.add_argument("--list", action="store_true", help="list fixtures and what each one is for")
    ap.add_argument("--report", nargs="+", type=Path, help="checker markdown reports to grade")
    ap.add_argument("--apply-to", type=Path, help="apply the fixture patch to a git worktree at this path")
    args = ap.parse_args()

    if args.list:
        return cmd_list()
    if not args.fixture:
        ap.print_help()
        return 2
    if args.apply_to:
        return cmd_apply(args.fixture, args.apply_to)
    if args.report:
        return cmd_score(args.fixture, args.report)
    ap.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
