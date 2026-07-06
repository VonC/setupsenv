# The distribution model

<img src="../assets/logo-senv-transparent.png" alt="" height="90" align="right">

senv maintainers work with Git. Team members, most of the time, do not:
they receive the environment as a single self-extracting archive,
`senv_<profile>-zip.exe`, published on a file share, next to a small
bootstrap `s.bat`. This page explains why distribution works that way and
how the two sides, publishing and consuming, stay in step.

## Why a file share and an archive, not a git clone

The constraints of the target environment drive the choice:

- **Day-one access.** A new contractor on a locked-down laptop may have no
  Git credentials, no access to the corporate Git server, and no rights to
  request either quickly. A read-only file share is usually the one thing
  that already works. Running one `s.bat` from the share must be enough.
- **No admin, no installer.** A 7-Zip self-extractor is just a file that
  unpacks itself where the user says: no elevation, no registry, exactly
  the senv philosophy applied to senv itself.
- **Everything in one piece.** The archive contains the full senv tree,
  custom repository included, so engine, team configuration and profile
  definitions cannot drift apart between users. (The flip side, the
  archive is as sensitive as the custom repository, is discussed in
  [public-engine-private-data.md](public-engine-private-data.md).)
- **Awkward networks.** VDI setups, proxies and offline pockets make "clone
  from the internet" unreliable, while an internal share is reachable from
  the same places the users work in. Tool archives are published to the
  same share for the same reason: installing a JDK should not require
  internet access, only the share.

Git remains the source of truth on the maintainer side; the share is a
distribution surface, not a history.

## The version handshake

With no Git on the consumer side, freshness has to be checked explicitly.
The mechanism is one small file:

- at build time, `adm\build.bat` writes a combined `git describe` of the
  senv and custom repositories into `custom\version`, and publishes a copy
  next to the archive on the share,
- on a user machine, `profile.bat` compares the local `custom\version`
  with the remote one and says whether an update is waiting (or, for a
  maintainer, whether a local commit still needs publishing),
- the remote bootstrap `s.bat` calls `remote_setup.bat`, which performs the
  same comparison and only downloads and re-extracts the archive when the
  versions differ: updates cost one file copy, checks cost almost nothing.

The version string is deliberately a description of two repositories at
once: it pins the engine and the team data as a pair, which a plain version
number on either side alone could not do.

## Push side and pull side

- **Push (maintainer):** `adm\build.bat <profile>` packs and publishes the
  archive plus the bootstrap files; `adm\build_all.bat` loops over every
  profile. `adm\publish.bat` and `adm\publish_profile.bat` do the same for
  individual tool archives, so each team share carries exactly the tools
  its `install_<profile>.list` names. See
  [../how-to/build-and-publish-a-profile-archive.md](../how-to/build-and-publish-a-profile-archive.md).
- **Pull (user):** inside a session, `up` refreshes the current profile
  from the share, `upg` is the quick Git-only variant, `upa` refreshes
  everything. Each of them ends up re-running setup, which is safe by
  construction: shared files are regenerated, personal `*.local.*` files
  are preserved (see
  [configuration-layers.md](configuration-layers.md)).

Nothing pushes to users automatically. A user updates when they choose to,
from a session they control, consistent with the general principle that
senv touches nothing outside the session.

## 👉 Where to look next

- [../how-to/update-senv-and-diagnose-version-drift.md](../how-to/update-senv-and-diagnose-version-drift.md) for the user-side
  update commands.
- [../tutorials/04-from-zero-on-a-team-laptop.md](../tutorials/04-from-zero-on-a-team-laptop.md)
  for the first bootstrap from a team share.
