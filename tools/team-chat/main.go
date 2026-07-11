// teams-reader: extract locally cached New Teams (Teams 2.x) chat messages
// from the Chromium IndexedDB LevelDB store, decoding BOTH the recent
// write-ahead-log records and the older compacted SST records (which a raw
// byte scan cannot read because of LevelDB's Snappy block compression).
//
// It opens a *copy* of the store with goleveldb (which handles Snappy + SST +
// journal replay), iterates every record, decodes the V8-serialized message
// fields, then writes a plain-text transcript grouped by conversation.
package main

import (
	"bytes"
	"encoding/binary"
	"flag"
	"fmt"
	"html"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
	"time"
	"unicode/utf16"

	"github.com/syndtr/goleveldb/leveldb"
	"github.com/syndtr/goleveldb/leveldb/opt"
)

// ---- V8 / Blink serialized-value decoding -----------------------------------

// V8 "one-byte" strings are Latin1 (e.g. accented French 'Ã©' = 0xE9). We map
// each byte to the same Unicode code point; Go stores the result as UTF-8.
func latin1(b []byte) string {
	r := make([]rune, len(b))
	for i, c := range b {
		r[i] = rune(c)
	}
	return string(r)
}

func utf16le(b []byte) string {
	if len(b)%2 != 0 {
		b = b[:len(b)-1]
	}
	u := make([]uint16, len(b)/2)
	for i := range u {
		u[i] = uint16(b[2*i]) | uint16(b[2*i+1])<<8
	}
	return string(utf16.Decode(u))
}

// unsigned LEB128 varint starting at i
func uvarint(b []byte, i int) (val, next int, ok bool) {
	var shift uint
	v := 0
	for {
		if i >= len(b) {
			return 0, 0, false
		}
		c := b[i]
		i++
		v |= int(c&0x7f) << shift
		if c&0x80 == 0 {
			break
		}
		shift += 7
		if shift > 35 {
			return 0, 0, false
		}
	}
	return v, i, true
}

// read a V8 string whose tag byte is at position p:
//
//	0x22 = one-byte (Latin1) string, 0x63 = two-byte (UTF-16LE) string
func readV8(b []byte, p int) (string, bool) {
	if p < 0 || p >= len(b) {
		return "", false
	}
	switch b[p] {
	case 0x22:
		l, ni, ok := uvarint(b, p+1)
		if !ok || l < 0 || ni+l > len(b) {
			return "", false
		}
		return latin1(b[ni : ni+l]), true
	case 0x63:
		l, ni, ok := uvarint(b, p+1)
		if !ok || l < 0 || ni+l > len(b) {
			return "", false
		}
		return utf16le(b[ni : ni+l]), true
	}
	return "", false
}

// readTimeAt reads a timestamp value whose tag is at p. Two encodings occur:
//   - ISO-8601 string (0x22/0x63)         -> in the write-ahead-log records
//   - float64 epoch-millis (0x4E 'N' tag) -> in the compacted "messages" store
func readTimeAt(b []byte, p int) (time.Time, bool) {
	var zero time.Time
	if p < 0 || p >= len(b) {
		return zero, false
	}
	switch b[p] {
	case 0x22, 0x63:
		s, ok := readV8(b, p)
		if !ok || !isoRe.MatchString(s) {
			return zero, false
		}
		if t, err := time.Parse("2006-01-02T15:04:05.999Z07:00", s); err == nil {
			return t, true
		}
		if t, err := time.Parse(time.RFC3339, s); err == nil {
			return t, true
		}
		return zero, false
	case 0x4E: // 'N' = IEEE-754 double, little-endian
		if p+9 > len(b) {
			return zero, false
		}
		f := math.Float64frombits(binary.LittleEndian.Uint64(b[p+1 : p+9]))
		ms := int64(f)
		if ms < 1000000000000 || ms > 4000000000000 { // ~2001..2096 sanity
			return zero, false
		}
		return time.UnixMilli(ms), true
	}
	return zero, false
}

// find every occurrence of a key encoded as 0x22 <len> <keyAscii>; return the
// byte offset just AFTER the key (where the value's own tag byte begins).
func findKeyStarts(b []byte, key string) []int {
	needle := append([]byte{0x22, byte(len(key))}, []byte(key)...)
	var res []int
	from := 0
	for {
		idx := bytes.Index(b[from:], needle)
		if idx < 0 {
			break
		}
		pos := from + idx
		res = append(res, pos+len(needle))
		from = pos + 1
	}
	return res
}

func nearest(pos []int, anchor, window int) int {
	best, bestd := -1, 1<<62
	for _, p := range pos {
		d := p - anchor
		if d < 0 {
			d = -d
		}
		if d < bestd && d <= window {
			bestd, best = d, p
		}
	}
	return best
}

// ---- message shaping --------------------------------------------------------

var (
	breakRe  = regexp.MustCompile(`(?i)<br\s*/?>`)
	blockRe  = regexp.MustCompile(`(?i)</(?:p|div|li|h[1-6]|tr)>`)
	tagRe    = regexp.MustCompile(`<[^>]+>`)
	spaceRe  = regexp.MustCompile(`[ \t\f\v]+`)
	threadRe = regexp.MustCompile(`19:[^;"]+?(?:unq\.gbl\.spaces|thread\.v2|thread\.skype|thread\.tacv2)`)
	isoRe    = regexp.MustCompile(`^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}`)
)

func stripHTML(s string) string {
	s = strings.ReplaceAll(s, "\r\n", "\n")
	s = strings.ReplaceAll(s, "\r", "\n")
	s = breakRe.ReplaceAllString(s, "\n")
	s = blockRe.ReplaceAllString(s, "\n")
	s = tagRe.ReplaceAllString(s, "")
	s = html.UnescapeString(s)
	s = strings.ReplaceAll(s, "\u00a0", " ")

	lines := strings.Split(s, "\n")
	clean := make([]string, 0, len(lines))
	for _, line := range lines {
		line = strings.TrimSpace(spaceRe.ReplaceAllString(line, " "))
		if line == "" && (len(clean) == 0 || clean[len(clean)-1] == "") {
			continue
		}
		clean = append(clean, line)
	}
	for len(clean) > 0 && clean[len(clean)-1] == "" {
		clean = clean[:len(clean)-1]
	}
	return strings.Join(clean, "\n")
}

func parseThread(s string) string { return threadRe.FindString(s) }

// system call/meeting event payloads are stored in the same content field but
// are not chat messages (e.g. {"eventtime":...,"initiator":...,"members":[...]})
func isSystemPayload(text string) bool {
	if !strings.HasPrefix(text, "{") {
		return false
	}
	for _, k := range []string{`"eventtime"`, `"initiator"`, `"members"`, `"eventType"`, `"callId"`} {
		if strings.Contains(text, k) {
			return true
		}
	}
	return false
}

type Msg struct {
	When   time.Time
	Author string
	Text   string
	Thread string
	Id     string
}

const window = 8000

// The write-ahead-log records use lowercase field names; the compacted
// "messages" store uses camelCase. We search for both.
var (
	nameKeys = []string{"imdisplayname", "imDisplayName"}
	timeKeys = []string{"composetime", "composeTime", "originalarrivaltime", "originalArrivalTime", "clientArrivalTime", "clientarrivaltime"}
	idKeys   = []string{"clientmessageid", "clientMessageId"}
)

func findAny(v []byte, keys []string) []int {
	var res []int
	for _, k := range keys {
		res = append(res, findKeyStarts(v, k)...)
	}
	return res
}

// extract all message triplets contained in one stored value blob
func extractFromValue(v []byte, out *[]Msg) {
	if !bytes.Contains(v, []byte("content")) {
		return
	}
	contentPos := findKeyStarts(v, "content")
	if len(contentPos) == 0 {
		return
	}
	namePos := findAny(v, nameKeys)
	timePos := findAny(v, timeKeys)
	idPos := findAny(v, idKeys)

	// one thread per stored value (messages/conversations stores): take the first id we can read
	thread := ""
	for _, p := range findKeyStarts(v, "conversationId") {
		if s, ok := readV8(v, p); ok {
			if t := parseThread(s); t != "" {
				thread = t
				break
			}
		}
	}
	if thread == "" {
		for _, p := range findKeyStarts(v, "conversationLink") {
			if s, ok := readV8(v, p); ok {
				if t := parseThread(s); t != "" {
					thread = t
					break
				}
			}
		}
	}
	if thread == "" {
		thread = "(no conversation id)"
	}

	for _, cp := range contentPos {
		raw, ok := readV8(v, cp)
		if !ok {
			continue
		}
		text := stripHTML(raw)
		if text == "" || isSystemPayload(text) {
			continue
		}
		tp := nearest(timePos, cp, window)
		if tp < 0 {
			continue
		}
		when, ok := readTimeAt(v, tp)
		if !ok {
			continue
		}
		author := ""
		if np := nearest(namePos, cp, window); np >= 0 {
			author, _ = readV8(v, np)
		}
		id := ""
		if ip := nearest(idPos, cp, window); ip >= 0 {
			id, _ = readV8(v, ip)
		}
		*out = append(*out, Msg{When: when.Local(), Author: author, Text: text, Thread: thread, Id: id})
	}
}

// ---- db copy + open ---------------------------------------------------------

func copyDBToTemp(src string) (string, error) {
	dst, err := os.MkdirTemp("", "teamsdb_")
	if err != nil {
		return "", err
	}
	entries, err := os.ReadDir(src)
	if err != nil {
		return "", err
	}
	for _, e := range entries {
		if e.IsDir() || e.Name() == "LOCK" {
			continue // skip the lock so goleveldb can open its own copy
		}
		data, err := os.ReadFile(filepath.Join(src, e.Name()))
		if err != nil {
			continue // a file vanished mid-copy; skip it
		}
		if err := os.WriteFile(filepath.Join(dst, e.Name()), data, 0644); err != nil {
			return "", err
		}
	}
	return dst, nil
}

func defaultDBPath() string {
	if configured := os.Getenv("TEAM_CHAT_DB_PATH"); configured != "" {
		return configured
	}
	la := os.Getenv("LOCALAPPDATA")
	p := filepath.Join(la, `Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\EBWebView\WV2Profile_tfw\IndexedDB\https_teams.microsoft.com_0.indexeddb.leveldb`)
	if _, err := os.Stat(p); err == nil {
		return p
	}
	return filepath.Join(la, `Packages\MSTeams_8wekyb3d8bbwe\LocalCache\Microsoft\MSTeams\EBWebView\Default\IndexedDB\https_teams.microsoft.com_0.indexeddb.leveldb`)
}

func main() {
	var (
		dbPath = flag.String("db", "", "path to the Teams IndexedDB .leveldb dir (default: auto-detect)")
		date   = flag.String("date", time.Now().Format("2006-01-02"), "day to extract, yyyy-mm-dd (ignored with -all/-since)")
		since  = flag.String("since", "", "start day yyyy-mm-dd (inclusive) for a range export")
		until  = flag.String("until", "", "end day yyyy-mm-dd (inclusive); default today when -since is set")
		all    = flag.Bool("all", false, "export every cached message, all dates")
		out    = flag.String("out", "", "output .txt path (default: ./teams-chat-<tag>.txt)")
		minMsg = flag.Int("min", 1, "skip conversations with fewer than this many messages")
		dump   = flag.String("dump", "", "DEBUG: dump raw structure of values containing this substring, then exit")
		find   = flag.String("find", "", "DEBUG: list decoded content/time/thread for values containing this substring, then exit")
		cover  = flag.Bool("coverage", false, "list every cached conversation with its message count and cached date range, then exit")
		stdout = flag.Bool("stdout", false, "write the transcript to standard output instead of a file")
	)
	flag.Usage = func() {
		fmt.Fprint(os.Stderr, `teams-reader - extract locally cached New Teams (Teams 2.x) chat messages.

Reads the Chromium IndexedDB LevelDB store, decoding BOTH the recent
write-ahead-log records and the older compacted (Snappy) SST records, so it
recovers the full conversation history currently held on disk - not just the
last few messages. Output is plain UTF-8 text, grouped by conversation.

Note: it can only read what Teams has already fetched locally. Teams keeps
roughly the last ~2 months of chats you have opened; to include messages older
than that, scroll them into view in Teams first (that pulls them into the cache).

Usage:
  teams-reader [flags]

Flags:
`)
		flag.PrintDefaults()
		fmt.Fprint(os.Stderr, `
Examples:
  teams-reader                              today -> ./teams-chat-<today>.txt
  teams-reader -date 2026-07-05             a specific day
  teams-reader -all -out C:\tmp\all.txt     everything cached, all dates
  teams-reader -min 3                       hide conversations with < 3 messages
`)
	}
	flag.Parse()

	src := *dbPath
	if src == "" {
		src = defaultDBPath()
	}
	if _, err := os.Stat(src); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: Teams store not found at %s\n", src)
		os.Exit(1)
	}

	tmp, err := copyDBToTemp(src)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR copying store: %v\n", err)
		os.Exit(1)
	}
	defer os.RemoveAll(tmp)

	// Open read-write on the throwaway copy so the journal (recent messages) is
	// replayed alongside the compacted SST files (older messages).
	db, err := leveldb.OpenFile(tmp, &opt.Options{})
	if err != nil {
		db, err = leveldb.RecoverFile(tmp, nil)
		if err != nil {
			fmt.Fprintf(os.Stderr, "ERROR opening store: %v\n", err)
			os.Exit(1)
		}
	}
	defer db.Close()

	if *find != "" {
		iter := db.NewIterator(nil, nil)
		var totVals, withContent, contentRecs int
		for iter.Next() {
			v := iter.Value()
			if !bytes.Contains(v, []byte(*find)) {
				continue
			}
			totVals++
			cps := findKeyStarts(v, "content")
			if len(cps) == 0 {
				continue
			}
			withContent++
			buf := make([]byte, len(v))
			copy(buf, v)
			// decode threads present
			var threads []string
			for _, p := range append(findKeyStarts(buf, "conversationId"), findKeyStarts(buf, "conversationLink")...) {
				if s, ok := readV8(buf, p); ok {
					if t := parseThread(s); t != "" {
						threads = append(threads, t)
					}
				}
			}
			fmt.Printf("\n== value len=%d  content-keys=%d  threads=%v ==\n", len(buf), len(cps), threads)
			for _, cp := range cps {
				raw, ok := readV8(buf, cp)
				if !ok {
					fmt.Printf("   content@%d: <unreadable tag %02x>\n", cp, buf[cp])
					continue
				}
				tp := nearest(findAny(buf, timeKeys), cp, window)
				ts := "NO-TIME"
				if when, ok := readTimeAt(buf, tp); ok {
					ts = when.Local().Format("2006-01-02 15:04:05")
				}
				txt := stripHTML(raw)
				if len(txt) > 55 {
					txt = txt[:55]
				}
				contentRecs++
				fmt.Printf("   [%s] %q\n", ts, txt)
			}
		}
		iter.Release()
		fmt.Printf("\nSUMMARY: %d values matched, %d had content, %d content records\n", totVals, withContent, contentRecs)
		return
	}

	if *dump != "" {
		iter := db.NewIterator(nil, nil)
		shown := 0
		for iter.Next() && shown < 3 {
			v := iter.Value()
			idx := bytes.Index(v, []byte(*dump))
			if idx < 0 {
				continue
			}
			shown++
			fmt.Printf("\n===== value len=%d, match at %d =====\n", len(v), idx)
			lo := idx - 400
			if lo < 0 {
				lo = 0
			}
			hi := idx + 400
			if hi > len(v) {
				hi = len(v)
			}
			seg := v[lo:hi]
			// ascii view (non-printables as '.')
			ascii := make([]byte, len(seg))
			for i, c := range seg {
				if c >= 32 && c < 127 {
					ascii[i] = c
				} else {
					ascii[i] = '.'
				}
			}
			fmt.Printf("ASCII: %s\n", string(ascii))
			// hex view
			var hx strings.Builder
			for _, c := range seg {
				fmt.Fprintf(&hx, "%02x ", c)
			}
			fmt.Printf("HEX: %s\n", hx.String())
		}
		iter.Release()
		return
	}

	var msgs []Msg
	iter := db.NewIterator(nil, nil)
	for iter.Next() {
		v := iter.Value()
		buf := make([]byte, len(v))
		copy(buf, v)
		extractFromValue(buf, &msgs)
	}
	iter.Release()
	if err := iter.Error(); err != nil {
		fmt.Fprintf(os.Stderr, "WARN iterator: %v\n", err)
	}

	// coverage: what does the cache actually hold, per conversation?
	if *cover {
		type cov struct {
			label  string
			thread string
			n      int
			min    time.Time
			max    time.Time
		}
		agg := map[string]*cov{}
		seenC := map[string]bool{}
		for _, m := range msgs {
			var k string
			if m.Id != "" {
				k = "id:" + m.Id
			} else {
				k = m.Thread + "|" + m.When.Format("2006-01-02T15:04") + "|" + m.Author + "|" + m.Text
			}
			if seenC[k] {
				continue
			}
			seenC[k] = true
			c := agg[m.Thread]
			if c == nil {
				c = &cov{thread: m.Thread, min: m.When, max: m.When}
				agg[m.Thread] = c
			}
			c.n++
			if m.When.Before(c.min) {
				c.min = m.When
			}
			if m.When.After(c.max) {
				c.max = m.When
			}
			if m.Author != "" && !strings.Contains(c.label, m.Author) {
				if c.label != "" {
					c.label += ", "
				}
				c.label += m.Author
			}
		}
		var list []*cov
		for _, c := range agg {
			list = append(list, c)
		}
		sort.Slice(list, func(i, j int) bool { return list[i].max.After(list[j].max) })
		now := time.Now()
		fmt.Printf("Cached conversations: %d\n", len(list))
		fmt.Printf("(AGE = days since newest cached message; open+scroll a chat in Teams to refresh it)\n\n")
		fmt.Printf("%-5s  %-6s  %-16s  %-16s  %s\n", "MSGS", "AGE", "OLDEST", "NEWEST", "PARTICIPANTS / thread")
		for _, c := range list {
			label := c.label
			if label == "" {
				label = "(unknown)"
			}
			ageDays := int(now.Sub(c.max).Hours() / 24)
			age := fmt.Sprintf("%dd", ageDays)
			if ageDays >= 2 {
				age += "*" // stale: likely missing newer messages until you open/scroll it
			}
			fmt.Printf("%-5d  %-6s  %-16s  %-16s  %s\n", c.n, age,
				c.min.Format("2006-01-02 15:04"), c.max.Format("2006-01-02 15:04"), label)
			fmt.Printf("%-5s  %-6s  %-16s  %-16s  %s\n", "", "", "", "", c.thread)
		}
		return
	}

	// date window: -all (none), -since/-until (range), or single -date
	var haveWindow bool
	var wStart, wEnd time.Time
	scope := "ALL dates"
	tag := "all"
	if !*all {
		haveWindow = true
		if *since != "" {
			wStart, err = time.ParseInLocation("2006-01-02", *since, time.Local)
			if err != nil {
				fmt.Fprintf(os.Stderr, "ERROR bad -since: %v\n", err)
				os.Exit(1)
			}
			endDay := time.Now()
			if *until != "" {
				endDay, err = time.ParseInLocation("2006-01-02", *until, time.Local)
				if err != nil {
					fmt.Fprintf(os.Stderr, "ERROR bad -until: %v\n", err)
					os.Exit(1)
				}
			}
			wEnd = time.Date(endDay.Year(), endDay.Month(), endDay.Day(), 23, 59, 59, 0, time.Local)
			scope = wStart.Format("2006-01-02") + " .. " + wEnd.Format("2006-01-02")
			tag = wStart.Format("20060102") + "-" + wEnd.Format("20060102")
		} else {
			d, e := time.ParseInLocation("2006-01-02", *date, time.Local)
			if e != nil {
				fmt.Fprintf(os.Stderr, "ERROR bad -date: %v\n", e)
				os.Exit(1)
			}
			wStart = d
			wEnd = time.Date(d.Year(), d.Month(), d.Day(), 23, 59, 59, 0, time.Local)
			scope = *date
			tag = *date
		}
	}

	// dedupe (content-based so WAL copy + compacted copy + client/server copies collapse)
	seen := map[string]bool{}
	byThread := map[string][]Msg{}
	total := 0
	for _, m := range msgs {
		if haveWindow && (m.When.Before(wStart) || m.When.After(wEnd)) {
			continue
		}
		// dedupe the same message seen in multiple stores (WAL vs compacted vs
		// conversation.lastMessage). Prefer the stable message id; otherwise fall
		// back to a coarse time bucket since compose/arrival times differ by ms.
		var key string
		if m.Id != "" {
			key = "id:" + m.Id
		} else {
			key = m.Thread + "|" + m.When.Format("2006-01-02T15:04") + "|" + m.Author + "|" + m.Text
		}
		if seen[key] {
			continue
		}
		seen[key] = true
		byThread[m.Thread] = append(byThread[m.Thread], m)
		total++
	}

	// order conversations by most-recent message first, keeping only >= min
	type grp struct {
		thread string
		msgs   []Msg
		latest time.Time
	}
	var groups []grp
	for th, ms := range byThread {
		if len(ms) < *minMsg {
			continue
		}
		sort.Slice(ms, func(i, j int) bool { return ms[i].When.Before(ms[j].When) })
		groups = append(groups, grp{thread: th, msgs: ms, latest: ms[len(ms)-1].When})
	}
	sort.Slice(groups, func(i, j int) bool { return groups[i].latest.After(groups[j].latest) })

	// write (scope and tag were computed with the date window above)
	outPath := *out
	if outPath == "" {
		outPath = fmt.Sprintf("teams-chat-%s.txt", tag)
	}

	var sb strings.Builder
	fmt.Fprintf(&sb, "# Teams cached messages  |  %s  |  %d message(s) across %d conversation(s)\n", scope, total, len(groups))
	fmt.Fprintf(&sb, "# Extracted: %s\n", time.Now().Format("2006-01-02 15:04:05"))
	fmt.Fprintf(&sb, "# Source: %s\n", src)
	sb.WriteString("# Reads both recent (journal) and older (compacted) cached messages.\n\n")

	for _, g := range groups {
		parts := map[string]bool{}
		for _, m := range g.msgs {
			if m.Author != "" {
				parts[m.Author] = true
			}
		}
		var pl []string
		for p := range parts {
			pl = append(pl, p)
		}
		sort.Strings(pl)
		label := strings.Join(pl, ", ")
		if label == "" {
			label = "(participants unknown)"
		}
		sb.WriteString(strings.Repeat("#", 80) + "\n")
		fmt.Fprintf(&sb, "## Conversation: %s\n", label)
		fmt.Fprintf(&sb, "## thread: %s  |  %d message(s)\n", g.thread, len(g.msgs))
		sb.WriteString(strings.Repeat("#", 80) + "\n")
		for _, m := range g.msgs {
			fmt.Fprintf(&sb, "[%s] %s: %s\n", m.When.Format("2006-01-02 15:04:05"), m.Author, m.Text)
		}
		sb.WriteString("\n")
	}

	transcript := strings.ReplaceAll(sb.String(), "\n", "\r\n")
	if *stdout {
		fmt.Print(transcript)
		return
	}

	// UTF-8 BOM so Windows tools (Notepad, Excel, PowerShell 5.1 Get-Content)
	// detect the encoding and render accented characters correctly.
	data := append([]byte{0xEF, 0xBB, 0xBF}, []byte(transcript)...)
	if err := os.WriteFile(outPath, data, 0644); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR writing %s: %v\n", outPath, err)
		os.Exit(1)
	}
	fmt.Printf("Wrote %d message(s) across %d conversation(s) to %s\n", total, len(groups), outPath)
}
