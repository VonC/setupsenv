# How to scan a project's dependencies for vulnerabilities

<img src="../assets/logo-senv-applications-transparent.png" alt="" height="90" align="right">

Goal: check the dependencies of a working tree against known
vulnerabilities, development dependencies included, the way GitHub's
Dependabot alerts do, but on demand and on your machine.

senv installs two scanners for that, both reading the lock files of Python
(`uv.lock`, requirements files), Go (`go.mod`), Node (npm, yarn and pnpm
lock files) and Maven (`pom.xml`):

- [Trivy](https://github.com/aquasecurity/trivy) scans a whole folder in a
  few seconds; it downloads its database from container registries,
- [Grype](https://github.com/anchore/grype) downloads its database over
  plain HTTPS, from `grype.anchore.io`; use it where a proxy blocks the
  registries Trivy needs.

Neither is in a team list: each person who wants one installs it.

## 📋 Steps with Trivy

1. Download and install it:

   ```cmd
   dwl trivy
   inst trivy
   ```

   `trivy.exe` lands in `%PRGS%\trivys\current`.

2. Give it short names in your own aliases (`aliase`, then `aliasr`; see
   [add a personal alias](add-personal-alias-or-env-var.md)):

   ```text
   trivy="%PRGS%\trivys\current\trivy.exe" $*
   vulns="%PRGS%\trivys\current\trivy.exe" fs --scanners vuln --include-dev-deps $* .
   ```

3. From the root of the working tree, scan it:

   ```cmd
   vulns
   ```

   which runs `trivy fs --scanners vuln --include-dev-deps .`. Without
   `--include-dev-deps`, Trivy leaves out the packages only reached from
   development groups (`[dependency-groups]` of `pyproject.toml` for uv),
   and some alerts are on exactly those packages.

   The first run downloads the vulnerability database, then each run
   refreshes it once it is out of date. If that download fails with
   `403 Forbidden`, see [behind a proxy](#behind-a-proxy-that-blocks-container-registries).

4. Narrow the report when needed; flags go before the `.` of the alias:

   ```cmd
   vulns --severity HIGH,CRITICAL
   vulns --ignore-unfixed
   vulns --format json --output vulns.json
   vulns --exit-code 1
   ```

   `--exit-code 1` makes a scan with findings fail, for a check script.
   List the CVE ids you accepted, one per line, in a `.trivyignore` file at
   the root.

## 📋 Steps with Grype

1. Download and install it:

   ```cmd
   dwl grype
   inst grype
   ```

   `grype.exe` lands in `%PRGS%\grypes\current`.

2. Add its aliases:

   ```text
   grype="%PRGS%\grypes\current\grype.exe" $*
   gvulns="%PRGS%\grypes\current\grype.exe" file:uv.lock $*
   ```

3. From the root of a uv project, scan its lock file:

   ```cmd
   gvulns
   ```

   Grype has no development dependency switch: it always reports on every
   package of the lock file, development groups included. The first run
   downloads its database (`grype db status` shows it), then each run
   checks for a newer one.

4. Point it at another lock file, or narrow the report:

   ```cmd
   grype file:go.mod
   grype file:package-lock.json
   gvulns --only-fixed --fail-on high
   gvulns -o json --file gvulns.json
   ```

   `--fail-on high` makes the run exit with code 2 on a finding of that
   severity or above.

Scan a lock file rather than the folder: `grype dir:.` reads every file of
the working tree, ignored ones included, and on a tree with generated
outputs it takes many minutes where `file:uv.lock` takes seconds.

## What they read, what they skip

| | Trivy | Grype |
| --- | --- | --- |
| `uv.lock` | every package with `--include-dev-deps`, runtime ones without | every package |
| requirements files | only one named exactly `requirements.txt` | any `*requirements*.txt` (`requirements-dev.txt`, `dev-requirements.txt`...) |
| `requirements.lock` or another name | skipped | skipped |
| ignored files | scanned: it walks the folder, not the Git index | scanned in `dir:` mode |

To scan a requirements file with another name, copy it as
`requirements.txt` into an empty folder and scan that folder.

To see what Trivy finds without its vulnerability database, list the
packages only:

```cmd
trivy fs --scanners license --skip-db-update --list-all-pkgs --include-dev-deps --format json --output pkgs.json .
```

Each entry of `Results` gives a file (`Target`), its type and its packages.

## Behind a proxy that blocks container registries

Trivy publishes its database as an OCI artifact: it downloads it from
container registries, `mirror.gcr.io` first. A corporate proxy that blocks
that category answers `403 Forbidden` with its own HTML page, and the other
public copies (`ghcr.io`, `public.ecr.aws`) usually share the block. `ti`
still succeeds, since the proxy itself works. Trivy's database has no
official copy outside those registries.

Then:

- use Grype, whose database comes from an ordinary HTTPS site,
- ask the security team to allow the registry, naming the scanner and the
  URL of the 403 (`https://mirror.gcr.io/v2/`),
- or point Trivy at a registry mirror of your company, if it has one (a
  Nexus or Artifactory proxy of `mirror.gcr.io` or `ghcr.io`):

  ```cmd
  vulns --db-repository registry.example.corp/aquasec/trivy-db:2
  ```

Trivy's air-gapped mode (a database copied into its cache, then
`--skip-db-update`) also works, where the security policy allows bringing
the database in.

## ✅ Check

- `trivy --version` and `grype version` print their versions.
- `vulns` ends with a table of findings per lock file instead of a `FATAL`
  line; the package listing above counts more packages with
  `--include-dev-deps` than without it as soon as the project has
  development dependencies.
- `gvulns` prints a table of findings, or `No vulnerabilities found`.

Related: [work behind a corporate proxy](work-behind-a-corporate-proxy.md),
[find the GitHub repositories you watch](find-custom-watched-github-repositories.md).
