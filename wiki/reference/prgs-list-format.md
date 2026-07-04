# prgs.list file format

`bin\prgs.list` is the catalog of programs that `dwl`, `inst_prg` and `div`
know about. One line per program, five `~`-separated fields; the first line
of the file is the schema itself:

```text
Name/alias1/alias2/...~version1/version2/...~folders_name~pattern~global
```

## Fields

| # | Field | Content |
| --- | --- | --- |
| 1 | names | display name, then aliases, separated by `/`; matching is case-insensitive |
| 2 | versions | allowed versions, or `#` for "any version or latest" |
| 3 | folders_name | family folder under `%PRGS%`, always ending with `s` |
| 4 | pattern | filename glob of the downloadable archive; `/` separates alternatives |
| 5 | global | optional marker: part of the base tool set installed for everyone |

Details:

- the program id (`prg_id`) is `folders_name` minus its trailing `s`
  (`codexs` gives `codex`); it must match a `:dwl_<id>` label in
  `bin\dwl.bat`,
- in field 2, a version may carry an `-LTS` marker (`21-LTS`); the keyword
  `lts` on the command line resolves through it,
- a bare major or cycle (`22`, `3.13`) is accepted when it prefixes a listed
  version,
- underscores in field 1 stand for spaces in the display name
  (`Sysinternals_Suite`).

A program can also be resolved from a concrete filename: when no name
matches, the pattern field of every line is tried against the given string
(`parse_prgs_list_for_pattern.ps1`); exactly one line must match.

## Current catalog

| Name | Aliases | Folder | Fixed versions |
| --- | --- | --- | --- |
| Gum | | `gums` | |
| Git | | `gits` | |
| Go | golang | `gos` | |
| GH (GitHub CLI) | gh | `ghs` | |
| JDK (Java) | java, jdk | `javas` | 11-24, `21-LTS` |
| Eclipse | eclipse | `eclipses` | |
| Chrome | | `chromiums` | |
| Peazip | pz, 7z | `peazips` | |
| Firefox | ff | `firefoxs` | |
| LazyGit | lazygit, lg, lzg, lz | `lazygits` | |
| Node | | `nodes` | 10-24, `22-LTS` |
| Python | py | `pythons` | 3.12, 3.13 |
| Sysinternals Suite | sysinternals, sys, sysint | `sysinternalsSuites` | |
| VSCode | code | `vscodes` | |
| SQL Developer | sqldeveloper, sqldev | `sqldevelopers` | |
| Graphviz | gv, dot, neato | `graphvizs` | |
| IntelliJ IDEA Community | idea, intellij | `ideas` | |
| Notepad++ | npp, notepadplusplus | `npps` | |
| Filezilla | fz | `filezillas` | |
| MobaXTerm | moba, mobax | `mobaxterms` | |
| Postman | | `postmans` | |
| putty | | `puttys` | |
| shellcheck | | `shellchecks` | |
| ZoomIt | zi | `zoomits` | |
| WinSCP | | `winscps` | |
| superfile | spf | `superfiles` | |
| Maven | mvn | `mavens` | |
| Terminal | term, cmd | `terminals` | |
| Git-Cliff | gitcliff, gcliff, cliff | `git-cliffs` | |
| ripgrep | rg | `ripgreps` | |
| Wildfly | wf, wfly | `wildflys` | |
| Git_Cred | gitcred, gitcreds | `gits` | |
| Lsd | ll, ls, lsd | `lsds` | |
| Bat | cat | `bats` | |
| fd | find | `fds` | |
| PowerToys | pt, toys, toy | `powertoys` | |
| TreeSize | ts | `treesizes` | |
| Mods | mod | `modss` | |
| jq | | `jqs` | |
| XrmToolBox | xrm, xrmtb | `xrmtoolboxs` | |
| drawio-desktop | drawio | `drawios` | |
| Artifactory | arti | `artifactorys` | |
| Nexus | nx, nex | `nexuss` | |
| Moar | more | `moars` | |
| Riff | diff | `riffs` | |
| msys | msys2 | `msys2s` | |
| tailwind | tailwindcss, tailw | `tailwindcsss` | |
| ffmpeg | ffm, ffmp | `ffmpegs` | |
| Codex | cdx | `codexs` | |

Programs marked `global` in the file: Gum, Git, Peazip, Sysinternals Suite,
VSCode, Notepad++, Git-Cliff, Git_Cred, jq, Codex. An empty "Fixed versions"
cell means `#` (any version, `latest` by default).

To add a program, see the how-to guide
[Add a program to prgs.list](../how-to/add-a-program-to-prgs-list.md).
