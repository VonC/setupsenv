package main

import (
	"strings"
	"testing"
)

func TestStripHTMLPreservesLinesAndNormalizesSpaces(t *testing.T) {
	got := stripHTML("<p>first&nbsp;line<br>second\u00a0line</p><div>third   line</div>")
	want := "first line\nsecond line\nthird line"
	if got != want {
		t.Fatalf("stripHTML() = %q, want %q", got, want)
	}
	if strings.ContainsRune(got, '\u00a0') {
		t.Fatal("stripHTML() retained a non-breaking space")
	}
}

func TestStripHTMLCollapsesRepeatedBlankLinesOnly(t *testing.T) {
	got := stripHTML("one<br><br><br>two")
	want := "one\n\ntwo"
	if got != want {
		t.Fatalf("stripHTML() = %q, want %q", got, want)
	}
}
