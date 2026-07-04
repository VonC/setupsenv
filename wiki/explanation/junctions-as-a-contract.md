# Junctions as a path contract

Every tool senv knows about is reachable through one single path shape:

```text
%PRGS%\<tool>s\<version>     a real folder, one per installed version
%PRGS%\<tool>s\current       a junction pointing at the active version
```

`%PRGS%\javas\jdk21`, `%PRGS%\nodes\node22`, `%PRGS%\gits\current`,
`%PRGS%\vscodes\current` — the family folder is the tool name plus a trailing
`s`, versions sit next to each other, and a junction names the one in use.
This page explains why that convention, small as it looks, carries most of
the system.

## A contract between producers and consumers

Scripts, aliases, project files and people all *consume* tool locations:
`switchjdk` prepends `%PRGS%\javas\<selected>\bin` to the PATH, a project
`senv.bat` points `JAVA_HOME` at a known folder, the editor variable resolves
`%PRGS%\vscodes\current\bin\code.cmd`. None of them should care how the tool
got there. On the *producer* side the reality is messy:

- most tools are archives uncompressed by `inst_prg`, sometimes with the
  content nested one folder deeper than expected,
- some tools were installed by a real Windows installer, under
  `Program Files` or a per-user location, outside `%PRGS%` entirely,
- some archives unpack under names that change with every release.

The junction is the adapter between the two sides. Whatever the physical
location, `check_prg_symlink.bat` makes `%PRGS%\<tool>s\<name>` point at it:
it detects the "single nested subfolder" case and re-targets the junction at
the real content, and `installs\check_symlink.bat` handles the `system` case
by looking the install path up in the registry and junctioning `current` to
that external folder. Consumers keep one path shape; producers keep their
freedom.

## Versioned names and `current`

The two naming styles serve two different needs:

- `current` answers "give me the tool, I do not care which version" — the
  right choice for editors, terminals, one-version utilities.
- versioned junctions and folders (`jdk21`, `node22`, `mvn3.9.9`) answer
  "give me exactly this version" — the raw material for the `switchxxx`
  commands, which list what is present, pick one, and put only that one on
  the session PATH. Several versions coexist without conflict because
  nothing global ever points at any of them.

A project can therefore pin versions with confidence: the path
`%PRGS%\javas\jdk17` means the same thing on every laptop that follows the
convention, even if one laptop installed it from an archive and another
junctioned it from a corporate install.

## Why not the registry, or the PATH?

Windows already has ways to find installed software — the registry, `App
Paths`, the global PATH filled by installers. senv avoids depending on them
for the same reason it rebuilds the PATH (see
[why-a-minimal-path.md](why-a-minimal-path.md)): on a locked-down laptop
those sources are unmanaged, machine-specific and often stale. The registry
is still consulted once, at junction-creation time, for `system` tools — but
after that single lookup the knowledge is frozen into a junction, and every
later consumer uses the plain filesystem contract instead of re-doing
registry queries.

## Edge case: drives without junction support

Junctions do not work on network drives. When `%PRGS%` lives on one, the
scripts fall back to renaming the extracted folder to the junction name and
recording the original name in a `_<folder>` marker file. The contract —
"the path shape is stable" — survives; only the mechanism changes. That
fallback is also a reminder that the contract is the point, not the NTFS
feature: anything that keeps `%PRGS%\<tool>s\<name>` valid is acceptable.

## Where to look next

- [../how-to/reference-an-already-installed-tool.md](../how-to/reference-an-already-installed-tool.md)
  to junction a tool that a corporate installer already put on the machine.
- [../reference/naming-conventions.md](../reference/naming-conventions.md)
  for the exact folder and junction naming rules per tool family.
