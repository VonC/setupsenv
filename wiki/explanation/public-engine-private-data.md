# Public engine, private data

senv is split into two repositories with two different lives:

- **senv** (this repository) is public. It contains the engine — session
  activation, download and install scripts, version switching, build
  tooling — plus a curated list of publicly downloadable tools. Nothing in
  it names a company, a proxy, a network share or a certificate.
- **custom** is private. It is a second, independent Git repository nested
  at `custom\` inside the senv folder, with its own `.git` and its own
  remote (a corporate server, or no remote at all). It carries everything
  the public side must not: proxy configuration, share paths, CA bundles,
  trust stores, internal Maven and IDE settings, and the per-team
  application lists.

The parent `.gitignore` excludes the whole folder with `/*custom*/`, so the
private tree cannot be committed to the public history even by accident.

## Why nested, not a submodule

A submodule would record the private repository's URL and commit hashes in
the public history — exactly the kind of corporate breadcrumb the split is
meant to avoid. Nesting an ignored repository keeps the two histories
completely disjoint: the public side does not know the private side exists,
while the private side still sits where the scripts expect it, at a fixed
relative path. The price is that nothing version-locks the pair; the build
tooling compensates by recording a combined `git describe` of both
repositories in `custom\version` at publish time.

The one submodule senv does use, `batcolors`, is the opposite case: public
code depending on public code, where a recorded URL is harmless.

## The seed: custom_example

`custom_example\` is the only part of the custom world that lives in the
public repository, precisely because it contains no data — a
`setup.ini.bat` template that detects the folder locations (`PRGS`, `HOME`,
`PROG`, `REMOTE_HOME`) and asks for confirmation, without a single
site-specific value in it. The first run of `setup.bat` copies it to
`custom\` when that folder is missing, so a new user (or a new company)
starts from a neutral skeleton and adds sensitive material only on the
private side. See
[../../custom_example/README.md](../../custom_example/README.md) for the
file conventions that grow from that seed.

The same logic pushed the generic machinery out of the private side over
time: the distribution scripts (`remote_setup.bat`, `ss.bat`,
`senv_update.bat`, `setup.senv.local.pre.bat`) are maintained in
`adm\custom\`, the share resolver in `installs\setupsdir.bat`, and the
local-proxy wrappers in `bin\`. The private repository keeps only what no
one else could share — and may still override an `adm\custom\` script by
carrying a file with the same name.

## How the boundary is kept in practice

The discipline is structural, not just a policy:

- corporate install steps live in `custom\<tool>s.pre|install|post.bat`
  hooks, which the public installer calls by name when present — the public
  `installs\` hooks stay generic,
- team environment and aliases live in `senv.custom.*` files, copied into
  `%HOME%\bin` at setup and sourced at each activation — the public
  `senv.bat` only knows the naming pattern, never the content,
- network shares are resolved by `setupsdir_<profile>.bat` scripts that
  exist only in custom.

A useful test when adding a file: "could this line appear on a public
GitHub page without anyone at the company minding?" If not, it belongs in
custom.

## The trust consequence

`adm\build.bat` packs the **whole senv tree, custom included**, into the
self-extracting `senv_<profile>-zip.exe` used for team distribution (see
[distribution-model.md](distribution-model.md)). That is what makes a
one-file bootstrap possible, but it also means every built archive is as
sensitive as the custom repository itself. The archives are therefore
published only to internal shares, never committed (`builds\` is ignored),
and the same care applies to any copy that leaves the share.

## Where to look next

- [../how-to/create-a-team-profile.md](../how-to/create-a-team-profile.md)
  to populate a custom repository for a team.
- [configuration-layers.md](configuration-layers.md) for how custom content
  is layered between the public engine and personal settings.
