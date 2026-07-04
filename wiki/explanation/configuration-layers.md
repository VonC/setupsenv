# The four configuration layers

A senv session is assembled from four layers, each owned by a different
actor and each able to override the one before it:

1. **senv** — the public engine: `bin\senv.bat`, the global aliases in
  `senv.doskey`, the curated tool list. Owned by the senv maintainers.
2. **custom** — the private team repository nested in `custom\`: shared
  settings that may be corporate-sensitive (proxy variables, certificate
  paths). Owned by the team administrator. See
  [public-engine-private-data.md](public-engine-private-data.md).
3. **profile** — the per-team slice of custom: `senv.custom.<profile>.bat`
  and `senv.custom.<profile>.doskey`, selected by the one-line
  `custom\profile` file. Owned by one team.
4. **local** — the personal files in `%HOME%\bin`: `senv.local.pre.bat`,
  `senv.local.bat`, `senv.local.doskey`, `gsenv.local.bat`. Owned by the
  individual user.

## Load order is precedence

`bin\senv.bat` sources the environment scripts in a fixed order:
`senv.custom.bat`, then `senv.local.bat`, then
`senv.custom.<profile>.bat`. The doskey macro files load the same way:
`senv.doskey`, then `senv.custom.doskey`, then `senv.local.doskey`, then
`senv.custom.<profile>.doskey`. In batch, the last `set` or the last macro
definition wins, so precedence is simply a consequence of ordering: team
settings override engine defaults, and personal settings override team
defaults for plain variables and aliases.

The design intent behind the ordering is pragmatic rather than dogmatic: the
profile layer loads late because a team bundle must be able to finish the
job (a Maven home, a truststore option) on top of whatever the generic team
file set up, while the personal `senv.local.bat` sits between them so a user
can adjust the generic team values without fighting their own profile.

## Regenerated versus preserved

The layer system only works across updates because `setup.bat` splits the
files in `%HOME%\bin` into two categories:

- **regenerated** — on every run, `setup.bat` copies `bin\*` from the senv
  repository and `*.custom.*` from the custom repository into `%HOME%\bin`,
  overwriting what was there. Engine scripts and team configuration are
  therefore always fresh, and files belonging to other profiles are pruned so
  one custom repository can serve many teams.
- **preserved** — the four `*.local.*` files are written only `if not exist`.
  The first setup seeds them (for example `senv.local.pre.bat` receives the
  authoritative `PRGS`, `HOME`, `PROG` and `REMOTE_HOME` values), and every
  later setup leaves them alone.

This create-once rule is the whole update contract: running `s`, `up` or a
new profile archive can replace every shared file, yet a user's personal
PATH additions, variables and aliases survive untouched. The only exceptions
are surgical: `setup.bat` re-inserts the `cdi` and `cdis` aliases into
`senv.local.doskey`, and the HOME migration rewrites the `HOME` and
`REMOTE_HOME` lines in `senv.local.pre.bat`.

## Why the split matters

- A senv upgrade must never cost a user their customizations, or nobody
  updates. Preservation is structural (files never rewritten), not a merge
  algorithm that could go wrong.
- A team administrator can push new proxy settings or aliases to everyone by
  publishing a new custom revision, without knowing anything about any
  individual laptop.
- A user experimenting locally cannot break teammates: the local layer lives
  only in their `%HOME%\bin` and is not part of any published artifact.

One boundary worth knowing: `senv.local.pre.bat` is special. It loads first
of all (before the PATH is even rebuilt) because it defines where everything
is — `PRGS`, `HOME`, `PROG`. It is personal in ownership but foundational in
role, which is why setup seeds it rather than leaving it empty.

## Where to look next

- [../how-to/add-personal-alias-or-env-var.md](../how-to/add-personal-alias-or-env-var.md)
  to add your own variables and aliases the update-proof way.
- [../how-to/create-a-team-profile.md](../how-to/create-a-team-profile.md)
  for the profile file conventions.
- [../reference/naming-conventions.md](../reference/naming-conventions.md)
  for the exact file names of each layer.
