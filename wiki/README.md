# senv wiki

Documentation for [senv](../README.md), organized on the
[Diátaxis](https://diataxis.fr/) model. The discipline is simple: each page
belongs to exactly one of the four categories below, and never mixes goals:
a tutorial teaches, a how-to guide solves, a reference describes, an
explanation clarifies.

## Tutorials

Learning by doing: follow the steps in order, type what is shown, check what
you see. Start here if senv is new to you.

- [Your first senv](tutorials/01-your-first-senv.md)
- [Install and use a tool on demand](tutorials/02-install-and-use-a-tool-on-demand.md)
- [Give a project its own senv](tutorials/03-give-a-project-its-own-senv.md)
- [From zero on a team laptop](tutorials/04-from-zero-on-a-team-laptop.md)

## How-to guides

Recipes for a precise goal, for readers who already know the basics.

- [Add a program to prgs.list](how-to/add-a-program-to-prgs-list.md)
- [Write an install hook](how-to/write-an-install-hook.md)
- [Reference an already-installed tool](how-to/reference-an-already-installed-tool.md)
- [Create a team profile](how-to/create-a-team-profile.md)
- [Build and publish a profile archive](how-to/build-and-publish-a-profile-archive.md)
- [Add a personal alias or environment variable](how-to/add-personal-alias-or-env-var.md)
- [Migrate HOME to a local drive](how-to/migrate-home-to-local.md)
- [Work behind a corporate proxy](how-to/work-behind-a-corporate-proxy.md)
- [Manage Python virtual environments](how-to/manage-python-virtual-environments.md)
- [Open project tabs in Windows Terminal](how-to/open-project-tabs-in-windows-terminal.md)
- [Update senv and diagnose version drift](how-to/update-senv-and-diagnose-version-drift.md)

## Reference

Exact, dry descriptions of commands, formats and conventions.

- [Commands](reference/commands.md)
- [prgs.list format](reference/prgs-list-format.md)
- [install_&lt;profile&gt;.list format](reference/install-list-format.md)
- [Naming conventions](reference/naming-conventions.md)
- [Environment variables](reference/environment-variables.md)
- [Doskey aliases](reference/doskey-aliases.md)
- [Git configuration](reference/git-configuration.md)
- [Exit codes](reference/exit-codes.md)

## Explanation

Background and reasoning: why senv is built the way it is.

- [Why a minimal PATH](explanation/why-a-minimal-path.md)
- [Configuration layers](explanation/configuration-layers.md)
- [Junctions as a contract](explanation/junctions-as-a-contract.md)
- [Public engine, private data](explanation/public-engine-private-data.md)
- [Anatomy of a session](explanation/anatomy-of-a-session.md)
- [Distribution model](explanation/distribution-model.md)
- [Why senv detects and wakes network drives](explanation/why-drive-detection.md)
