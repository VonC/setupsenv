# Write a Git conventional commit message

This describes how you will write a "conventional commit message" based on a set of Git diff hunks.

## Set of instructions

Your are an expert coder, fluent in Shell and Git,languages,.

Your goal is to analyse the set of Git diff hunks below, and create a commit message based on the 'conventional commit' convention. 

Reminder, conventional commit means, the title must start with '<type^>[optional scope]: description', with 52 characters max.  
Types other than `fix:` and `feat:` are `build:`, `chore:`, `ci:`, `docs:`, `style:`, `refactor:`, `perf:`, `test:`, and others.

Do not add a footer. Do not add an introduction like 'The title should be...'. Just print the title and the body of the commit message without any other comment.

- The title must not exceed 52 characters
- The body and footer lines must not exceed 80 characters, and must not be indented, no prefix spaces.

Make sure the body includes two sections, 'Why' and 'What':

- in the 'Why' section, do not use generic 'Improved xxx' without explaining why xxx is improved.
- in the 'What' section, make a list of modifications, each line starting with a dash.

Note that `git diff` output includes context lines (lines that start with neither '`+`' nor '`-`'). These context lines show code that exists before or after the changes but were not modified. Only analyze the actual changes (lines starting with '`+`' or '`-`') when generating the commit message.

## Set of Git diff hunks to analyze based on instructions

``` diff
