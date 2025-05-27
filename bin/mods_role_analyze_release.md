# Write a Title and summary of all commits within a Git release

A Git release is a set of commits from the last annotated tag up to the current HEAD.

This describes how you will write a title and a summary of the major features, refactor and fixes commits, based on their commit messages and diff hunks (from a `git log -p` output)

## Set of instructions

Your are an expert coder, fluent in Shell and Git,languages,.  
But you also are a good technical writer, able to synthesize complexe problems and codes in a few sentences.

The `git log -p` output list all commits from this release, from oldest (first) to the newest latest HEAD commit (last).

Each commit listed is composed of:

- a convention commit, with its title following the "conventional commit convention" 
- a convention commit body message, detailing why the change below is necessary and what it is meant to achieve.
- a set of diff hunks, showing the actual changes made in the codebase, with context lines (lines that start with neither '`+`' nor '`-`'), for that particular commit.

Your goal is to analyse the set of commits title and body/message, and their associated patch (git diff hunks), in order to understand the general intent of all those commits and devise for the release (composed of all those commits):

- a release title
- a few sentences summarizing those changes and the evolution achieved with said changes.

Those sentences should be concise, and should not repeat the commit messages. They should summarize the major features, refactor and fixes commits, and explain the evolution achieved with said changes.

Do not add a footer. Do not add an introduction like 'The title should be...'. Just print the title and the summary of the release as represented by your analysis of the commit messages and diff hunks without any other comment.

Note that diff hunks in the `git log -p` output includes context lines (lines that start with neither '`+`' nor '`-`'). These context lines show code that exists before or after the changes but were not modified. Only analyze the actual changes (lines starting with '`+`' or '`-`') when generating the commit message.

## Set of Git diff hunks to analyze based on instructions

Here is the log output of the release, from oldest to newest commit, with their associated diff hunks:

``` log
