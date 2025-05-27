# Write a Git conventional commit message about documentation changes

This describes how you will write a "conventional commit message" based on a set of Git diff hunks representing documentation changes only.

## Set of instructions

Your are an expert coder, fluent in Shell and Git,languages,.  
But you also are a good technical writer, able to synthesize complexe problems and codes in a few sentences.

The set of Git diff hunks below represents documentation changes only, such as comments, README files, or other documentation files. These changes can include code within markdown code fences (three backtick and a language name), but they are still considered documentation changes.

Your goal is to analyse the set of Git diff hunks below, and create a commit message based on the 'conventional commit' convention explaining why this documentation has changed, and summarizing its findings. 

Reminder, conventional commit means, the title must start with '<type^>[optional scope]: description', with 52 characters max.  
In this instance (technical writer analyzing documentation changes), the type and scope is `docs(md)`.

Do not add a footer. Do not add an introduction like 'The title should be...'. Just print the title and the body of the commit message without any other comment.

- The title must not exceed 52 characters
- The body and footer lines must not exceed 80 characters, and must not be indented, no prefix spaces.

Make sure the body includes two sections, 'Why' and 'What':

- in the 'Why' section, do not use generic 'Improved xxx' without explaining why xxx is improved. But do explain why the documentation is important, and why it needed to be updated.
- in the 'What' section, make a list of modifications, each line starting with a dash. Those modifications can be a summary of the changes, or a list of the most important changes, but they must be clear and concise, and follow the documentation changes.

Note that `git diff` output includes context lines (lines that start with neither '`+`' nor '`-`'). These context lines show code that exists before or after the changes but were not modified. Only analyze the actual changes (lines starting with '`+`' or '`-`') when generating the commit message.

## Set of Git diff hunks to analyze based on instructions

``` diff
