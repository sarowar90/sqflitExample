"""What the findings parser must cope with.

Every deviation asserted here was produced by a real checker run against
fixtures/cart_checkout_atomicity.patch, not invented. The agents are told to
emit `### [Blocking] file:line`; what they actually emit drifts, and the parser
is the thing that absorbs that drift so the scorer never sees it.
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from review_eval.parser import Severity, parse_report


class ParseSeverityHeadings(unittest.TestCase):
    def test_bracketed_severity(self):
        """The documented format."""
        report = parse_report("## Correctness — 1 finding(s)\n\n### [Blocking] lib/db.dart:163\n**Breaks:** atomicity\n")
        self.assertEqual(len(report.findings), 1)
        self.assertEqual(report.findings[0].severity, Severity.BLOCKING)

    def test_bare_severity_without_brackets(self):
        """test-auditor emitted `### Blocking lib/...` — no brackets."""
        report = parse_report("## Tests — 1 finding(s)\n\n### Blocking lib/database_helper.dart:missing\n**Untested:** sellCart\n")
        self.assertEqual(len(report.findings), 1)
        self.assertEqual(report.findings[0].severity, Severity.BLOCKING)

    def test_should_fix_is_two_words(self):
        report = parse_report("## Correctness — 1 finding(s)\n\n### [Should fix] lib/providers.dart:102\n**Breaks:** drift\n")
        self.assertEqual(report.findings[0].severity, Severity.SHOULD_FIX)

    def test_severity_is_case_insensitive(self):
        report = parse_report("## Style — 1 finding(s)\n\n### [consider] lib/theme.dart:4\n**Convention:** tokens\n")
        self.assertEqual(report.findings[0].severity, Severity.CONSIDER)


class ParseLocation(unittest.TestCase):
    def test_file_and_line(self):
        report = parse_report("## Correctness — 1 finding(s)\n\n### [Blocking] lib/database_helper.dart:163\n**Breaks:** x\n")
        self.assertEqual(report.findings[0].file, "lib/database_helper.dart")
        self.assertEqual(report.findings[0].line, 163)

    def test_line_may_be_the_word_missing(self):
        """A missing test has no line. test-auditor writes `:missing`."""
        report = parse_report("## Tests — 1 finding(s)\n\n### Blocking lib/database_helper.dart:missing\n**Untested:** x\n")
        self.assertEqual(report.findings[0].file, "lib/database_helper.dart")
        self.assertIsNone(report.findings[0].line)

    def test_trailing_symbol_after_location_is_not_part_of_the_path(self):
        """invariant-checker appended ` — `sellCart`` to the heading."""
        report = parse_report("## Correctness — 1 finding(s)\n\n### [Blocking] lib/database_helper.dart:163 — `sellCart`\n**Breaks:** x\n")
        self.assertEqual(report.findings[0].file, "lib/database_helper.dart")
        self.assertEqual(report.findings[0].line, 163)


class ParseSections(unittest.TestCase):
    def test_section_name(self):
        report = parse_report("## Correctness — 2 finding(s)\n\n### [Blocking] a.dart:1\nx\n\n### [Consider] b.dart:2\ny\n")
        self.assertEqual(report.section, "Correctness")
        self.assertEqual(len(report.findings), 2)

    def test_no_findings_line_yields_nothing(self):
        report = parse_report("## Security — no findings\n\n## Insufficient context\nNone.\n")
        self.assertEqual(report.section, "Security")
        self.assertEqual(report.findings, [])

    def test_insufficient_context_is_never_a_finding(self):
        """security-scanner emitted `### Insufficient context` at h3, where
        findings live. Without this the scorer sees a phantom finding."""
        report = parse_report("## Security — no findings\n\n### Insufficient context\nNone.\n")
        self.assertEqual(report.findings, [])

    def test_prose_before_the_section_is_ignored(self):
        """invariant-checker prefixed its report with a line about confirming
        anchors before the `## Correctness` heading."""
        text = "Both anchors confirmed on base: sellProduct at 117-161.\n\n## Correctness — 1 finding(s)\n\n### [Blocking] a.dart:1\nx\n"
        report = parse_report(text)
        self.assertEqual(report.section, "Correctness")
        self.assertEqual(len(report.findings), 1)


class ParseBody(unittest.TestCase):
    def test_body_captures_everything_until_the_next_finding(self):
        text = (
            "## Correctness — 2 finding(s)\n\n"
            "### [Blocking] lib/database_helper.dart:163\n"
            "**Breaks:** Sale atomicity.\n"
            "**Failure:** Cart {A: 1, B: 99} commits A then fails B.\n\n"
            "### [Should fix] lib/providers.dart:102\n"
            "**Breaks:** State drift.\n"
        )
        report = parse_report(text)
        self.assertIn("atomicity", report.findings[0].body.lower())
        self.assertIn("commits a then fails b", report.findings[0].body.lower())
        self.assertNotIn("state drift", report.findings[0].body.lower())

    def test_body_stops_at_the_insufficient_context_section(self):
        text = (
            "## Correctness — 1 finding(s)\n\n"
            "### [Blocking] a.dart:1\n"
            "**Breaks:** atomicity\n\n"
            "## Insufficient context\n"
            "The bundle omitted sales_screen.dart.\n"
        )
        report = parse_report(text)
        self.assertNotIn("omitted", report.findings[0].body.lower())

    def test_searchable_text_includes_the_heading(self):
        """Matching on `sellCart` must work when the symbol is only named in
        the heading."""
        report = parse_report("## Correctness — 1 finding(s)\n\n### [Blocking] lib/db.dart:163 — `sellCart`\n**Breaks:** x\n")
        self.assertIn("sellcart", report.findings[0].searchable.lower())


class SeverityOrdering(unittest.TestCase):
    def test_blocking_outranks_should_fix_outranks_consider(self):
        self.assertGreater(Severity.BLOCKING, Severity.SHOULD_FIX)
        self.assertGreater(Severity.SHOULD_FIX, Severity.CONSIDER)

    def test_parses_from_string(self):
        self.assertEqual(Severity.from_text("should fix"), Severity.SHOULD_FIX)
        self.assertEqual(Severity.from_text("Should Fix"), Severity.SHOULD_FIX)
        self.assertEqual(Severity.from_text("should_fix"), Severity.SHOULD_FIX)


if __name__ == "__main__":
    unittest.main()
