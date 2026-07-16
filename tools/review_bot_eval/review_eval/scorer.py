"""Grades a run against a fixture's expectations.

A fixture passes when it catches everything in `must_flag`, says nothing
matching `must_not_flag`, and stays under `max_findings`. All three, or the
fixture fails — a bot that finds every bug and also comments on the weather is
a bot nobody reads, so noise is a failure, not a deduction.
"""

from __future__ import annotations

from dataclasses import dataclass, field

from .parser import Finding, Severity


@dataclass
class Result:
    fixture: str = ""
    missed: list[dict] = field(default_factory=list)   # must_flag that nothing matched
    noise: list[dict] = field(default_factory=list)    # must_not_flag that something matched
    matched: list[dict] = field(default_factory=list)
    over_budget: int | None = None
    findings_count: int = 0

    @property
    def passed(self) -> bool:
        return not self.missed and not self.noise and self.over_budget is None

    @property
    def summary(self) -> str:
        if self.passed:
            return f"PASS {self.fixture} — {len(self.matched)}/{len(self.matched)} caught, {self.findings_count} finding(s), no noise"
        parts = []
        if self.missed:
            parts.append(f"missed {len(self.missed)} ({', '.join(m['id'] for m in self.missed)})")
        if self.noise:
            parts.append(f"noise {len(self.noise)} ({', '.join(n['id'] for n in self.noise)})")
        if self.over_budget is not None:
            parts.append(f"{self.findings_count} findings over budget of {self.over_budget}")
        return f"FAIL {self.fixture} — " + "; ".join(parts)


def _file_matches(finding: Finding, expected: dict) -> bool:
    want = expected.get("file")
    return want is None or finding.file == want


def _lines_match(finding: Finding, expected: dict) -> bool:
    """`lines: [start, end]` scopes a rule to a range — the difference between
    *mentioning* unchanged code and filing a finding *against* it."""
    span = expected.get("lines")
    if span is None:
        return True
    if finding.line is None:
        return False
    return span[0] <= finding.line <= span[1]


def _keywords_match(finding: Finding, expected: dict) -> bool:
    haystack = finding.searchable.lower()
    return all(kw.lower() in haystack for kw in expected.get("keywords_all", []))


def _severity_matches(finding: Finding, expected: dict) -> bool:
    floor = expected.get("min_severity")
    return floor is None or finding.severity >= Severity.from_text(floor)


def _find(findings: list[Finding], expected: dict, check_severity: bool) -> Finding | None:
    for f in findings:
        if (
            _file_matches(f, expected)
            and _lines_match(f, expected)
            and _keywords_match(f, expected)
            and (not check_severity or _severity_matches(f, expected))
        ):
            return f
    return None


def score_fixture(findings: list[Finding], expectations: dict, fixture: str = "") -> Result:
    result = Result(fixture=fixture or expectations.get("fixture", ""), findings_count=len(findings))

    for expected in expectations.get("must_flag", []):
        hit = _find(findings, expected, check_severity=True)
        if hit is None:
            result.missed.append(expected)
        else:
            at = f"{hit.file}:{hit.line}" if hit.line is not None else hit.file
            result.matched.append({"id": expected["id"], "at": at})

    # Severity is irrelevant to noise: reporting known noise as a Consider is
    # still reporting it.
    for expected in expectations.get("must_not_flag", []):
        if _find(findings, expected, check_severity=False) is not None:
            result.noise.append(expected)

    budget = expectations.get("max_findings")
    if budget is not None and len(findings) > budget:
        result.over_budget = budget

    return result
