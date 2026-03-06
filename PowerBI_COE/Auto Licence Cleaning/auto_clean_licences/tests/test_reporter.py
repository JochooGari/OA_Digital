import csv
import os
import sys
import tempfile

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

import reporter


def test_export_dry_run_csv_creates_file():
    """Should create a CSV with correct headers and one row per user."""
    with tempfile.TemporaryDirectory() as tmpdir:
        path = os.path.join(tmpdir, "output", "report.csv")
        emails = ["user1@loreal.com", "user2@loreal.com"]

        reporter.export_dry_run_csv(emails, path)

        assert os.path.exists(path)
        with open(path, newline="", encoding="utf-8") as f:
            rows = list(csv.DictReader(f))

        assert len(rows) == 2
        assert rows[0]["email"] == "user1@loreal.com"
        assert rows[0]["action"] == "REVOKE_PRO_LICENCE"
        assert rows[1]["email"] == "user2@loreal.com"


def test_export_dry_run_csv_empty_list():
    """Should create a CSV with only headers when no users."""
    with tempfile.TemporaryDirectory() as tmpdir:
        path = os.path.join(tmpdir, "report.csv")
        reporter.export_dry_run_csv([], path)

        assert os.path.exists(path)
        with open(path, newline="", encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        assert rows == []


def test_export_live_summary_csv_creates_file():
    """Should create a CSV with execution status per user."""
    with tempfile.TemporaryDirectory() as tmpdir:
        path = os.path.join(tmpdir, "summary.csv")
        emails = ["a@loreal.com", "b@loreal.com"]
        summary = {"total": 2, "revoked": 2, "failed": 0, "errors": []}

        reporter.export_live_summary_csv(summary, emails, path)

        assert os.path.exists(path)
        with open(path, newline="", encoding="utf-8") as f:
            rows = list(csv.DictReader(f))
        assert len(rows) == 2
        assert rows[0]["status"] == "REVOKED"
