from __future__ import annotations

from datetime import date, datetime
import os
from pathlib import Path
import unittest

from copy_team_chat import append_novel, clean_teams_text, is_timestamp, prepare_daily_file

# cSpell:disable
class CleanTeamsTextTests(unittest.TestCase):
    def test_french_incoming_message_from_screenshot(self) -> None:
        copied = """the update was sent only to the added atten... par Example, Alice
Example, Alice
17:44

the update was sent only to the added attendee"""
        expected = "Example, Alice\n17:44\n\nthe update was sent only to the added attendee"
        self.assertEqual(clean_teams_text(copied), expected)

    def test_french_outgoing_message_from_screenshot(self) -> None:
        copied = """I do not see the invitee in your invitation thoug par Sample, Bob (Ext)
17:44
Sample, Bob (Ext)

I do not see the invitee in your invitation though"""
        expected = "Sample, Bob (Ext)\n17:44\n\nI do not see the invitee in your invitation though"
        self.assertEqual(clean_teams_text(copied), expected)

    def test_english_by_and_twelve_hour_timestamp(self) -> None:
        copied = """A longer sentence that has been trunca... by Jane Doe
Jane Doe
5:09 PM

A longer sentence that has been truncated in the preview."""
        expected = "Jane Doe\n5:09 PM\n\nA longer sentence that has been truncated in the preview."
        self.assertEqual(clean_teams_text(copied), expected)

    def test_french_and_english_localized_timestamps(self) -> None:
        self.assertTrue(is_timestamp("08/07 10:00"))
        self.assertTrue(is_timestamp("mercredi 15 juillet 2026 à 17:44"))
        self.assertTrue(is_timestamp("Wednesday, July 15, 2026 at 5:44 PM"))

    def test_real_day_month_sample_purges_all_truncated_previews(self) -> None:
        copied = """Hello Alice, how are you ? par Example, Bob
Example, Bob
08/07 09:59

Hello Alice, how are you ?

Did you see the updated email with new instructi... par Example, Bob
Example, Bob
08/07 10:00

Did you see the updated email with new instruction ?

I have sent the instru... par Sample, Rob...
08/07 10:01
Sample, Robert (Ext)

I have sent the instructions."""
        cleaned = clean_teams_text(copied)
        self.assertNotIn("...", cleaned)
        self.assertEqual(
            cleaned,
            "Example, Bob\n08/07 09:59\n\nHello Alice, how are you ?\n\n"
            "Example, Bob\n08/07 10:00\n\n"
            "Did you see the updated email with new instruction ?\n\n"
            "Sample, Robert (Ext)\n08/07 10:01\n\nI have sent the instructions.",
        )

    def test_reaction_and_composer_accessibility_duplicates_are_removed(self) -> None:
        copied = """👍
1 réaction J’aime.

Dispose d’un menu contextuel
Réponse aux participants externes.
Taper un message"""
        self.assertEqual(clean_teams_text(copied), "1 réaction J’aime.")

    def test_repeated_contiguous_block_is_removed(self) -> None:
        copied = """Jane Doe
17:44

Hello

Jane Doe
17:44

Hello"""
        self.assertEqual(clean_teams_text(copied), "Jane Doe\n17:44\n\nHello")


class AppendNovelTests(unittest.TestCase):
    def test_suffix_prefix_overlap_appends_only_new_part(self) -> None:
        existing = "Alice\n10:00\n\nFirst\n\nBob\n10:01\n\nSecond"
        fragment = "Bob\n10:01\n\nSecond\n\nAlice\n10:02\n\nThird"
        full, appended = append_novel(existing, fragment)
        self.assertEqual(appended, "Alice\n10:02\n\nThird")
        self.assertEqual(full, existing + "\n\n" + appended)

    def test_fragment_already_in_existing_is_ignored(self) -> None:
        existing = "Alice\n10:00\n\nFirst\n\nBob\n10:01\n\nSecond"
        full, appended = append_novel(existing, "Bob\n10:01\n\nSecond")
        self.assertEqual((full, appended), (existing, ""))


class DailyFileTests(unittest.TestCase):
    def test_keeps_today_file_and_truncates_stale_file(self) -> None:
        path = Path(__file__).with_name("test_daily_file.tmp")
        try:
            path.write_text("today", encoding="utf-8")
            self.assertEqual(prepare_daily_file(path, date.today()), "today")
            stale = datetime(2020, 1, 2, 12, 0).timestamp()
            os.utime(path, (stale, stale))
            self.assertEqual(prepare_daily_file(path, date.today()), "")
            self.assertEqual(path.read_text(encoding="utf-8"), "")
        finally:
            path.unlink(missing_ok=True)


if __name__ == "__main__":
    unittest.main()
