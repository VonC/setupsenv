# Install and use a tool on demand

In this tutorial you download a portable JDK and Node.js, uncompress them
under `%PRGS%`, and put a chosen version on the PATH of one session — while
other sessions stay untouched.

You need a working senv (see [Your first senv](01-your-first-senv.md)) and an
open session (`senv` typed in the current `CMD` window).

## 1. Download a tool

```cmd
dwl jdk 21
```

`dwl` finds the latest JDK 21 archive online and downloads it into
`%PRGS%\setup`. You see the download progress, then the archive name.

Do the same for Node.js:

```cmd
dwl node 22
```

Tools and versions come from a curated list; `dwl` alone (no argument) opens
a picker.

## 2. Install (uncompress) it

```cmd
inst jdk
inst node
```

`inst` uncompresses the downloaded archive under the family folder and names
the version folder by convention:

```text
%PRGS%\javas\jdk21
%PRGS%\nodes\node22
```

No installer ran, no registry was touched: install means uncompress.

You could also have done both steps at once with `div jdk 21`.

## 3. Put a version on the session PATH

```cmd
switchjdk 21
```

You should see the selected version, and `JAVA_HOME` now points at
`%PRGS%\javas\jdk21`. Check:

```cmd
java -version
echo %JAVA_HOME%
```

Same for Node:

```cmd
switchnode 22
node -v
```

If several versions are installed and you give no number, a picker lets you
choose. The switch commands only touch the current session: they remove any
previous `%PRGS%\javas` (or `nodes`) entry from the local PATH, then prepend
the chosen one.

## 4. See what changed — and what did not

Inspect the session PATH, entry by entry:

```cmd
ppath javas
```

You see the `%PRGS%\javas\jdk21\bin` entry, marked as existing.

Now open a **second** `CMD` window, type `senv`, then:

```cmd
java -version
```

The command is not found (or finds another default): the switch you did in
the first window changed nothing globally, and nothing outside senv sessions
was modified at any point.

## Next steps

- [Give a project its own senv](03-give-a-project-its-own-senv.md) to make a
  project select its versions automatically.
- All switch commands and their arguments:
  [Commands](../reference/commands.md).
- How the version folders and junctions are laid out:
  [Naming conventions](../reference/naming-conventions.md).
