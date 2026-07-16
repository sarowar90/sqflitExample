"""What "the bot behaved correctly" means, expressed as assertions.

Two halves, and the second matters as much as the first:

  must_flag     — the bug is in the diff and the bot has to say so
  must_not_flag — the bait is in the diff and the bot has to stay quiet

A bot that only satisfies must_flag is a bot that comments on everything.
REVIEW_POLICY.md §5 lists what it must ignore; must_not_flag is that list with
teeth.
"""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from review_eval.parser import Finding, Severity
from review_eval.scorer import score_fixture


def finding(severity, file, line=1, body=""):
    return Finding(severity=severity, file=file, line=line, heading="", body=body)


class MustFlag(unittest.TestCase):
    def test_passes_when_a_matching_finding_exists(self):
        result = score_fixture(
            findings=[finding(Severity.BLOCKING, "lib/database_helper.dart", 163, "no db.transaction wraps the writes")],
            expectations={
                "must_flag": [
                    {"id": "atomicity", "file": "lib/database_helper.dart",
                     "min_severity": "blocking", "keywords_all": ["transaction"]}
                ],
                "must_not_flag": [],
            },
        )
        self.assertTrue(result.passed)
        self.assertEqual(result.missed, [])

    def test_fails_when_the_bug_is_not_reported(self):
        result = score_fixture(
            findings=[],
            expectations={
                "must_flag": [
                    {"id": "atomicity", "file": "lib/database_helper.dart",
                     "min_severity": "blocking", "keywords_all": ["transaction"]}
                ],
                "must_not_flag": [],
            },
        )
        self.assertFalse(result.passed)
        self.assertEqual([m["id"] for m in result.missed], ["atomicity"])

    def test_fails_when_severity_is_too_low(self):
        """Reporting sale atomicity as a nitpick is not catching it."""
        result = score_fixture(
            findings=[finding(Severity.CONSIDER, "lib/database_helper.dart", 163, "no db.transaction here")],
            expectations={
                "must_flag": [
                    {"id": "atomicity", "file": "lib/database_helper.dart",
                     "min_severity": "blocking", "keywords_all": ["transaction"]}
                ],
                "must_not_flag": [],
            },
        )
        self.assertFalse(result.passed)
        self.assertEqual([m["id"] for m in result.missed], ["atomicity"])

    def test_higher_severity_than_required_still_passes(self):
        result = score_fixture(
            findings=[finding(Severity.BLOCKING, "lib/providers.dart", 102, "does not reload products")],
            expectations={
                "must_flag": [
                    {"id": "drift", "file": "lib/providers.dart",
                     "min_severity": "should fix", "keywords_all": ["reload"]}
                ],
                "must_not_flag": [],
            },
        )
        self.assertTrue(result.passed)

    def test_fails_when_reported_against_the_wrong_file(self):
        result = score_fixture(
            findings=[finding(Severity.BLOCKING, "lib/providers.dart", 102, "no db.transaction")],
            expectations={
                "must_flag": [
                    {"id": "atomicity", "file": "lib/database_helper.dart",
                     "min_severity": "blocking", "keywords_all": ["transaction"]}
                ],
                "must_not_flag": [],
            },
        )
        self.assertFalse(result.passed)

    def test_all_keywords_must_be_present(self):
        result = score_fixture(
            findings=[finding(Severity.BLOCKING, "lib/db.dart", 1, "writes are not atomic")],
            expectations={
                "must_flag": [
                    {"id": "atomicity", "file": "lib/db.dart",
                     "min_severity": "blocking", "keywords_all": ["atomic", "rollback"]}
                ],
                "must_not_flag": [],
            },
        )
        self.assertFalse(result.passed)

    def test_a_finding_without_a_line_reports_just_the_file(self):
        """security-scanner headed its real finding `lib/database_helper.dart —
        `searchProducts`` with no line at all."""
        result = score_fixture(
            findings=[Finding(severity=Severity.BLOCKING, file="lib/database_helper.dart", line=None, body="sql injection")],
            expectations={
                "must_flag": [
                    {"id": "injection", "file": "lib/database_helper.dart",
                     "min_severity": "blocking", "keywords_all": ["injection"]}
                ],
                "must_not_flag": [],
            },
        )
        self.assertTrue(result.passed)
        self.assertEqual(result.matched[0]["at"], "lib/database_helper.dart")

    def test_keyword_matching_ignores_case(self):
        result = score_fixture(
            findings=[finding(Severity.BLOCKING, "lib/db.dart", 1, "No DB.Transaction wrapper")],
            expectations={
                "must_flag": [
                    {"id": "atomicity", "file": "lib/db.dart",
                     "min_severity": "blocking", "keywords_all": ["transaction"]}
                ],
                "must_not_flag": [],
            },
        )
        self.assertTrue(result.passed)


class MustNotFlag(unittest.TestCase):
    def test_passes_when_the_bot_stays_quiet_about_known_noise(self):
        result = score_fixture(
            findings=[finding(Severity.BLOCKING, "lib/database_helper.dart", 163, "no db.transaction")],
            expectations={
                "must_flag": [],
                "must_not_flag": [
                    {"id": "dead-code", "keywords_all": ["_buildEmptyState"]}
                ],
            },
        )
        self.assertTrue(result.passed)

    def test_fails_when_the_bot_reports_documented_noise(self):
        """REVIEW_POLICY.md §5: the dashboard dead code is known and accepted.
        flutter analyze already warns about it."""
        result = score_fixture(
            findings=[finding(Severity.CONSIDER, "lib/screens/dashboard_screen.dart", 425, "_buildEmptyState is unused")],
            expectations={
                "must_flag": [],
                "must_not_flag": [
                    {"id": "dead-code", "keywords_all": ["_buildEmptyState"]}
                ],
            },
        )
        self.assertFalse(result.passed)
        self.assertEqual([n["id"] for n in result.noise], ["dead-code"])

    def test_a_missed_bug_and_a_noisy_comment_both_fail(self):
        result = score_fixture(
            findings=[finding(Severity.CONSIDER, "lib/screens/dashboard_screen.dart", 425, "_buildEmptyState is unused")],
            expectations={
                "must_flag": [
                    {"id": "atomicity", "file": "lib/database_helper.dart",
                     "min_severity": "blocking", "keywords_all": ["transaction"]}
                ],
                "must_not_flag": [
                    {"id": "dead-code", "keywords_all": ["_buildEmptyState"]}
                ],
            },
        )
        self.assertFalse(result.passed)
        self.assertEqual([m["id"] for m in result.missed], ["atomicity"])
        self.assertEqual([n["id"] for n in result.noise], ["dead-code"])

    def test_noise_may_be_scoped_to_a_file(self):
        """Naming `sellProduct` while explaining the bug is fine. Filing a
        finding *against* the unchanged sellProduct is not."""
        expectations = {
            "must_flag": [],
            "must_not_flag": [
                {"id": "unchanged-sellproduct", "file": "lib/database_helper.dart",
                 "keywords_all": ["sellProduct"], "lines": [117, 161]}
            ],
        }
        explaining = score_fixture(
            findings=[finding(Severity.BLOCKING, "lib/database_helper.dart", 163, "unlike sellProduct above, no transaction")],
            expectations=expectations,
        )
        self.assertTrue(explaining.passed)

        filing_against_it = score_fixture(
            findings=[finding(Severity.CONSIDER, "lib/database_helper.dart", 130, "sellProduct could be clearer")],
            expectations=expectations,
        )
        self.assertFalse(filing_against_it.passed)


class CleanFixture(unittest.TestCase):
    def test_silence_passes_a_fixture_with_nothing_to_find(self):
        result = score_fixture(findings=[], expectations={"must_flag": [], "must_not_flag": []})
        self.assertTrue(result.passed)

    def test_max_findings_caps_a_flood(self):
        """A 12-line diff answered with nine Considers has failed, however
        individually correct they are."""
        result = score_fixture(
            findings=[finding(Severity.CONSIDER, "lib/a.dart", i, f"nit {i}") for i in range(9)],
            expectations={"must_flag": [], "must_not_flag": [], "max_findings": 3},
        )
        self.assertFalse(result.passed)
        self.assertIn("9", result.summary)


if __name__ == "__main__":
    unittest.main()
