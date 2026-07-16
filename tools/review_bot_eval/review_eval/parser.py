"""Turns a checker's markdown report into findings the scorer can grade.

The agents are told to emit `### [Blocking] file:line`. They mostly do. The
drift this absorbs is real, observed output, not defensive guessing:

  - `### Blocking file:line`            (brackets dropped)
  - `### [Blocking] file:line — `sym``  (symbol appended)
  - `### Insufficient context`          (a section, at finding depth)
  - prose above the `## Section` heading

Tightening the prompts would remove some of this. It would not remove all of
it, and a scorer that trips on a missing bracket reports a bot failure that is
really a parser failure — the most expensive kind of wrong answer here.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field
from enum import IntEnum


class Severity(IntEnum):
    """Ordered so `>=` means "at least as serious as"."""

    CONSIDER = 1
    SHOULD_FIX = 2
    BLOCKING = 3

    @classmethod
    def from_text(cls, text: str) -> "Severity":
        key = re.sub(r"[\s_-]+", " ", text.strip().lower())
        try:
            return {"consider": cls.CONSIDER, "should fix": cls.SHOULD_FIX, "blocking": cls.BLOCKING}[key]
        except KeyError:
            raise ValueError(f"unknown severity: {text!r}") from None


@dataclass
class Finding:
    severity: Severity
    file: str
    line: int | None
    heading: str = ""
    body: str = ""

    @property
    def searchable(self) -> str:
        """Heading plus body. A finding often names its symbol only in the
        heading, and that is exactly what expectations match on."""
        return f"{self.heading}\n{self.body}"


@dataclass
class Report:
    section: str | None = None
    findings: list[Finding] = field(default_factory=list)


# `### [Blocking] path:163 — anything` / `### Blocking path:missing`
_FINDING_RE = re.compile(
    r"^###\s+"
    r"\[?(blocking|should\s+fix|consider)\]?\s+"
    r"([^\s:]+)"
    r"(?::(\d+|missing|none|n/a))?"
    r"(.*)$",
    re.IGNORECASE,
)

_SECTION_RE = re.compile(r"^##\s+(.+?)\s*(?:—|--|-)\s*(?:\d+\s+finding|no\s+findings)", re.IGNORECASE)
_ANY_H2_RE = re.compile(r"^##\s+(.+?)\s*$")

# Sections that live at h2 but that agents sometimes emit at h3, where findings
# live. Without this the scorer grades a heading as a phantom finding.
_NOT_A_FINDING = re.compile(r"^#{2,3}\s+(insufficient\s+context|notes?\b|gaps?\b)", re.IGNORECASE)


def parse_report(text: str) -> Report:
    """Parse one checker's report. Unparseable lines are ignored, not raised —
    a checker is free to add prose, and prose is not a finding."""
    report = Report()
    current: Finding | None = None
    body: list[str] = []

    def flush() -> None:
        nonlocal current, body
        if current is not None:
            current.body = "\n".join(body).strip()
            report.findings.append(current)
        current, body = None, []

    for line in text.splitlines():
        if _NOT_A_FINDING.match(line):
            flush()
            continue

        match = _FINDING_RE.match(line)
        if match:
            flush()
            severity, path, line_text, trailing = match.groups()
            current = Finding(
                severity=Severity.from_text(severity),
                file=path.strip("`"),
                line=int(line_text) if line_text and line_text.isdigit() else None,
                heading=line.lstrip("# ").strip(),
            )
            continue

        if line.startswith("## "):
            flush()
            if report.section is None:
                section = _SECTION_RE.match(line) or _ANY_H2_RE.match(line)
                if section:
                    report.section = section.group(1).strip()
            continue

        if current is not None:
            body.append(line)

    flush()
    return report


def parse_reports(texts: list[str]) -> list[Finding]:
    """Flatten several checkers' reports into one list for scoring."""
    return [f for text in texts for f in parse_report(text).findings]
