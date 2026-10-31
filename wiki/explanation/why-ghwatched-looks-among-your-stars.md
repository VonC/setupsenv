# Why ghwatched looks among your stars

<img src="../assets/logo-senv-applications-transparent.png" alt="" height="90" align="right">

GitHub's Watch menu offers *Participating and @mentions*, *All activity*,
*Ignore*, and *Custom*, where a few events are picked: issues, pull
requests, releases, discussions, security alerts. A custom watch is how one
follows a project for its releases without its issue traffic, and it is the
one GitHub's API does not list.

## What the API shows

- `GET /user/subscriptions`, the documented list of watched repositories,
  holds the *All activity* watches only. On one account, none of the 38
  repositories that had sent release notifications appeared in it.
- `GET /repos/{owner}/{repo}/subscription` answers 404 for a custom watch,
  the very answer it gives for a repository not watched at all.
- GraphQL's `viewer { watching }` holds the same repositories as the REST
  list.
- GraphQL's `Repository.viewerSubscription` is the one place where a custom
  watch shows: it is `SUBSCRIBED` for *All activity*, `UNSUBSCRIBED` for no
  watch, `IGNORED` for *Ignore*, and `null` for a custom watch. The schema
  allows the `null` without documenting what it means, so this may change.

Nothing lists the custom watches, so they have to be found by asking each
candidate repository for its `viewerSubscription`.

## Why stars are the candidates

A repository followed for its releases is usually one that was starred
first, and the starred list is cheap to read: one GraphQL request returns a
hundred starred repositories with their `viewerSubscription`, topics and
description, so a few thousand stars take a few dozen requests. On the same
account, every starred repository among those 38 came back `null`, and
archiving did not explain the other `null` values: 8 of 836 were archived.

The price is plain: a repository watched with a custom setting but never
starred is out of reach. The notification inbox can hint at some of them
(release notifications come from repositories with a releases watch), but
it only holds what arrived recently.

The `null` also says nothing about which custom events are picked: a
releases watch and a security alerts watch look the same.

## Why words match at a word start

Topics are kebab-case words (`supply-chain-security`) and descriptions are
prose, so a filter has to find stems inside both: `vulnerab` should find
`vulnerability` and `vulnerabilities`. A plain substring goes too far:
`auth` would find `oauth`, `pip` every `pipeline`. Matching where a word
starts keeps the stems and drops most accidents; `=pip` covers the short
words that still catch longer ones.
