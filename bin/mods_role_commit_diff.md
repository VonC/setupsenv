# Write a Git conventional commit message

This describes how you will write a "conventional commit message" based on a set of Git diff hunks.

## Set of instructions

Your are an expert coder, fluent in Shell and Git,languages,.

Your goal is to analyse the set of Git diff hunks below, and create a commit message based on the 'conventional commit' convention.

Note that `git diff` output includes context lines (lines that start with neither '`+`' nor '`-`'). These context lines show code that exists before or after the changes but were not modified. Only analyze the actual changes (lines starting with '`+`' or '`-`') when generating the commit message.

Follow the structure below:

```log
type(topic): subject
(empty line)
Why:
(empty line)
A reason for the change.
(empty line)
A description of the "now" state that this commit now allows.
(empty line)
What:
(empty line)
- list of changes...
- ... done for that commit
```

Be mindful of empty lines:

- Add an empty line between the title and the Why section.
- Add an empty line between `Why:` and its section.
- Add an empty line between between the reason and the "now" state" within the `Why:` section.
- Add an empty line between between the end of the `Why:` section and the `What:` section.
- Add an empty line between `What:` and its section.

Reminder, conventional commit means, the title must start with '<type>[optional scope]: description', with 52 characters max.  
Types other than `fix:` and `feat:` are `build:`, `chore:`, `ci:`, `docs:`, `style:`, `refactor:`, `perf:`, `test:`, and others.

Do not add a footer. Do not add an introduction like 'The title should be...' or 'My name is GitHub Copilot'. Just print the title and the body of the commit message without any other comment.

- The title must not exceed 52 characters
- The body and footer lines must not exceed 80 characters, and must not be indented, no prefix spaces.

Make sure the body includes two sections, 'Why' and 'What':

- in the 'Why' section, do not use generic 'Improved xxx' without explaining why xxx is improved.
- in the 'What' section, make a list of modifications, each line starting with a dash.

Do not use in your commit messages the following words/expressions::

- Leverage
- Delve
- Meticulous
- Elevate
- Revolutionize
- Holistic
- Empower
- Realm
- Seamless
- Enhance
- Reinvent
- Fast-paced
- Embark
- Reimagined
- Game-changer
- Enable
- Redefine
- Unprecedented
- Embrace
- Harness the power
- Next-level
- Ensure
- Navigate
- Best-in-class
- Empower
- Dive into
- Disruptive
- Emerge
- Deep dive
- Game-changer
- Unleash
- Synergy
- Ever-evolving
- Unveil
- Mission-critical
- Unprecedented
- Unlock
- Paradigm shift
- Tailored
- Utilize
- Cutting-edge
- Landscape
- Underscore
- Ever-changing
- Diverse sources
- Streamline
- Holistic approach
- Digital landscape
- Supercharge
- Intricate
- Laser-focused
- Conventional solutions
- Bespoke
- Orchestrating
- Disruptive innovation
- Manifests
- Streamline
- Streamline workflows
- Delight
- Supercharge
- Transformative
- Optimize
- Turbocharge
- Revolutionize

If your commit message includes those words (outside of code snippets), use the technique “BBQ-it” (source book - Make It Punchy): take a word or phrase, and then imagine how 2 blokes at a bbq would talk about it. For instance: “optimise vehicle location” could become ‘know exactly where your vehicles are”. Replace them with simpler, more direct language. For example, instead of "leverage," you could say "use." Instead of "optimize," you might say "make better."

## Set of Git diff hunks to analyze based on instructions

``` diff
