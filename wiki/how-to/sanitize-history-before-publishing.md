# How to sanitize the history before publishing

Goal: verify that no confidential word (person, company, internal host,
internal domain) survives anywhere in the repository history, then rewrite
that history with `git-filter-repo.bat` before making the repository public.

The process has two phases: an audit that scans every commit message, every
file path and every file version ever committed, then a rewrite driven by a
replacement file. All examples below use dummy words (`jdoe`, `acmecorp`,
`secretproject`): substitute your real list, and never commit that list.

## Phase 1: audit the full history

Run everything from the repository root in a Git Bash session. Start by
writing the watch list as one case-insensitive alternation, for example
`jdoe|acmecorp|secretproject|\.lan\b`. For each name, also watch plausible
misspellings (doubled or dropped letters, swapped vowels): for `smith`,
a tolerant pattern like `sm[iy]th?` also catches `smyth` and `smit` in a
commit typed by hand.

1. Scan commit and tag messages, on all refs:

   ```sh
   git log --all --format='%H %s %b' | grep -i -E 'jdoe|acmecorp|secretproject'
   git tag -l -n100 | grep -i -E 'jdoe|acmecorp|secretproject'
   ```

2. List the author and committer identities. A replacement file does not
   touch these: they are rewritten by a mailmap in phase 2.

   ```sh
   git log --all --format='%an|%ae|%cn|%ce' | sort -u
   ```

   For every identity to neutralize, add a line to a mailmap file (same
   gitignored naming rule, for example `a.mailmap.local.txt`). The standard
   `.mailmap` format applies: the email-only form maps the address and
   keeps the contributor name.

   ```text
   <jdoe@example.com> <jdoe@acmecorp.com>
   ```

   Verify the mapping before phase 2: the neutral identities must come out,
   and the untouched ones must stay unchanged.

   ```sh
   git -c mailmap.file="$(pwd)/a.mailmap.local.txt" log --all --use-mailmap \
     --format='%aN|%aE' | sort -u
   ```

3. Scan every file path ever tracked, not only the current tree:

   ```sh
   git rev-list --all --objects | cut -d' ' -f2- | sort -u \
     | grep -i -E 'jdoe|acmecorp|secretproject'
   ```

   While there, check that files ignored today (credentials, private
   configuration) were never committed in the past: grep the same path list
   for their names.

4. Scan every file version ever committed. Do not loop `git cat-file blob`
   per object (one process per blob is far too slow on Windows): collect the
   blob ids once, then stream them through a single `git cat-file --batch`
   into a small scanner. Save this as `scan.pl`:

   ```perl
   use strict; use warnings;
   binmode(STDIN);
   my $pat = qr/$ARGV[0]/i;
   my ($blobs, $hits) = (0, 0);
   while (my $hdr = <STDIN>) {
       chomp $hdr;
       my ($oid, $type, $size) = split / /, $hdr;
       last unless defined $size;
       my ($buf, $got) = ('', 0);
       while ($got < $size) {
           my $n = read(STDIN, $buf, $size - $got, $got);
           last unless $n;
           $got += $n;
       }
       my $lf; read(STDIN, $lf, 1);
       $blobs++;
       if ($buf =~ $pat) { print "$oid\n"; $hits++; }
   }
   print STDERR "scanned=$blobs hits=$hits\n";
   ```

   The inner `read` loop matters: a pipe may return fewer bytes than asked,
   and a single `read` silently truncates blobs. Then:

   ```sh
   git rev-list --all --objects | cut -d' ' -f1 | sort -u \
     | git cat-file --batch-check='%(objectname) %(objecttype)' \
     | awk '$2=="blob"{print $1}' > blobs.txt
   git cat-file --batch < blobs.txt | perl scan.pl 'jdoe|acmecorp|secretproject'
   ```

   This scans raw bytes, so binaries are covered too. To map a hit back to
   its path, look the blob id up in the `git rev-list --all --objects`
   output.

5. Validate the scanner before trusting a zero. Run it once with a word that
   certainly exists (the repository name, for instance) and confirm a large
   hit count. A scanner bug reads exactly like a clean history.

6. Sweep for what the watch list does not name. Grep the same blob stream
   for the shapes of leaks rather than known words: `https?://` URLs and
   their hosts, email addresses, IP addresses, UNC paths (`\\\\host\\share`),
   `C:\\Users\\<name>` paths, and lines around `password`, `secret`, `token`,
   `credential`, `proxy`, `ldap`. Review the unique matches by hand: expect
   only public URLs, placeholders like `example.corp`, and localhost.

## Phase 1 output: the replacement file

Write one rule per line, most specific first, in a file whose name matches a
gitignore pattern (here `a.*` and `*.local.*` both do), for example
`a.sensitive.replacements.local.txt`:

```text
# literal (case-sensitive) by default; regex: with (?i) for insensitive
regex:(?i)C:\\Users\\JDOE==>%USERPROFILE%
regex:(?i)jdoe==>user
regex:(?i)acmecorp==>acme
regex:(?i)secretproject==>projectx
regex:(?i)\.lan\b==>.corp
```

Keep a defensive rule for every watched word even when the audit found zero
hits: the rewrite then guarantees what the scan only observed. Confirm the
file can never be committed:

```sh
git check-ignore -v a.sensitive.replacements.local.txt
```

## Phase 2: rewrite with git-filter-repo

`git-filter-repo.bat` (in senv `bin\`) downloads the tool and runs it with
the senv Python. Work on a fresh clone: filter-repo refuses a repository
with remotes or local changes unless forced, and a bad rewrite on a clone
costs nothing.

```bat
git clone C:\path\to\repo repo-public
cd repo-public
git-filter-repo.bat --mailmap ..\a.mailmap.local.txt ^
                    --replace-message ..\a.sensitive.replacements.local.txt ^
                    --replace-text ..\a.sensitive.replacements.local.txt
```

`--replace-message` rewrites commit and tag messages, `--replace-text`
rewrites every historical blob, `--mailmap` rewrites the author and
committer identities from step 2. Then re-run the whole phase 1 audit on
the rewritten clone: it must come back empty. Only then add the public
remote and push.

If commits landed between the audit and the rewrite, re-scan at least that
delta first: broad rules like `regex:(?i)jdoe` substitute inside longer
words too, and must stay verified against real content.

## Check

On the rewritten clone, phase 1 reports zero hits for every watched word,
`git log --all` shows the neutral messages and the neutral emails, and
neither the replacement file nor the mailmap appears in `git ls-files`.

Related: [public engine, private data](../explanation/public-engine-private-data.md),
[distribution model](../explanation/distribution-model.md).
