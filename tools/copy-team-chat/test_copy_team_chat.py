from __future__ import annotations

from datetime import date, datetime
import os
from pathlib import Path
import unittest

from copy_team_chat import (
    clean_teams_text, is_timestamp, merge_transcript, prepare_daily_file,
)

# cSpell:disable
CHROME = """Votre message de statut apparaît dans les conversations et les canaux lorsque des personnes vous @mentionnent.

Comporte un menu contextuel
Conversation

Non lu(e)s
Canaux
Conversations

Comporte un menu contextuel
[PROJECT] Weekend tests

Conversation

Partagé

Récapitulatif
+2

Présente un menu contextuel
Rejoindre

24

Liste des messages
Appuyez sur Ctrl+F pour faire une recherche dans cette conversation
"""
ALICE_1 = "Example, Alice\nsamedi 14:01\n\nFirst"
BOB_2 = "Sample, Bob (Ext)\nsamedi 14:02\n\nSecond\n\n1 réaction J’aime."
ALICE_3 = "Example, Alice\nsamedi 14:03\n\nThird"
BOB_4 = "Sample, Bob (Ext)\nsamedi 14:04\n\nFourth"


def copy_of(*messages: str) -> str:
    return CHROME + "\n\n".join(messages) + "\n\nTaper un message"


def collect(*copies: str) -> tuple[str, list[int]]:
    transcript, counts = "", []
    for copied in copies:
        transcript, added, _ = merge_transcript(transcript, clean_teams_text(copied))
        counts.append(added)
    return transcript, counts


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


    def test_teams_chrome_before_the_message_list_is_removed(self) -> None:
        self.assertEqual(clean_teams_text(copy_of(ALICE_1, BOB_2)), ALICE_1 + "\n\n" + BOB_2)

    def test_polluted_transcript_keeps_each_message_once(self) -> None:
        polluted = (copy_of(ALICE_1, BOB_2, ALICE_3) + "\n\n" +
                    copy_of(BOB_2, ALICE_3, BOB_4))
        self.assertEqual(
            clean_teams_text(polluted),
            "\n\n".join((ALICE_1, BOB_2, ALICE_3, BOB_4)),
        )


class MergeTranscriptTests(unittest.TestCase):
    def test_suffix_prefix_overlap_appends_only_new_part(self) -> None:
        existing = "Alice\n10:00\n\nFirst\n\nBob\n10:01\n\nSecond"
        fragment = "Bob\n10:01\n\nSecond\n\nAlice\n10:02\n\nThird"
        full, added, updated = merge_transcript(existing, fragment)
        self.assertEqual(full, existing + "\n\nAlice\n10:02\n\nThird")
        self.assertEqual((added, updated), (1, 0))

    def test_fragment_already_in_existing_is_ignored(self) -> None:
        existing = "Alice\n10:00\n\nFirst\n\nBob\n10:01\n\nSecond"
        self.assertEqual(merge_transcript(existing, "Bob\n10:01\n\nSecond"), (existing, 0, 0))

    def test_overlapping_scroll_windows_keep_each_message_once(self) -> None:
        transcript, counts = collect(
            copy_of(ALICE_1, BOB_2, ALICE_3),
            copy_of(BOB_2, ALICE_3, BOB_4),
            copy_of(ALICE_3, BOB_4),
        )
        self.assertEqual(transcript, "\n\n".join((ALICE_1, BOB_2, ALICE_3, BOB_4)))
        self.assertEqual(counts, [3, 1, 0])

    def test_copy_scrolled_up_is_inserted_before_known_messages(self) -> None:
        transcript, counts = collect(copy_of(ALICE_3, BOB_4), copy_of(ALICE_1, BOB_2, ALICE_3))
        self.assertEqual(transcript, "\n\n".join((ALICE_1, BOB_2, ALICE_3, BOB_4)))
        self.assertEqual(counts, [2, 2])

    def test_new_reaction_updates_the_message_instead_of_duplicating_it(self) -> None:
        existing = ALICE_1 + "\n\n" + ALICE_3
        full, added, updated = merge_transcript(existing, ALICE_1 + "\n\n1 réaction Rigole.")
        self.assertEqual(full, ALICE_1 + "\n\n1 réaction Rigole.\n\n" + ALICE_3)
        self.assertEqual((added, updated), (0, 1))

    def test_message_cut_at_a_copy_edge_keeps_its_longest_version(self) -> None:
        longer = ALICE_1 + "\nLa réunion a commencé. à samedi 14:01."
        full, _, _ = merge_transcript(ALICE_1, longer)
        self.assertEqual(full, longer)
        self.assertEqual(merge_transcript(longer, ALICE_1), (longer, 0, 0))

    def test_follow_up_without_author_line_is_its_own_message(self) -> None:
        follow_up = "samedi 14:02\n\nimage"
        transcript, counts = collect(
            copy_of(ALICE_1, follow_up, BOB_2),
            copy_of(follow_up, BOB_2, ALICE_3),
        )
        self.assertEqual(transcript, "\n\n".join((ALICE_1, follow_up, BOB_2, ALICE_3)))
        self.assertEqual(counts, [3, 1])

    def test_distinct_messages_in_the_same_minute_are_kept(self) -> None:
        other = "Example, Alice\nsamedi 14:01\n\nAnother point"
        full, added, _ = merge_transcript(ALICE_1, other)
        self.assertEqual((full, added), (ALICE_1 + "\n\n" + other, 1))


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
