---
agent: ask
description: 'Group files and write a conventional commit message for each group.'
---

Your goal is to group files listed in the prompt, from least to most dependent and, for each group, to write a conventional commit message.

The context that can inform how you will group those files can be:

- the `plan.xxx.md` if present in your context, and the step(s) of that plan mentioned in prompt. Check if #file:../../docs/plan.current.md does apply.
- the `a.diff` if present in your context, with the recent evolutions done for those files listed in the prompt. Check if #file:../../a.diff does apply. 

Consider this `a.diff` in your context, and for each group, write a commit message, preceded by the list of files.

Each list of files must lists files with their relative pathname, one per line, with, for each line, `git add `, then a `&&` right before and right after the relative pathname of that file. Example:

```log
git add &&src/pdfss/.../file1.py&&
git add &&src/pdfss/.../file2.py&&
git add &&src/pdfss/.../file3.py&&
...
additional empty line
```

For each group, write a conventional commit message as specified in `.github\prompts\write-commit-message.prompt.md` ( #file:write-commit-message.prompt.md ), which means 52 chars for title, 80 chars max for each lines in the commit body message, and do not use words listed in the "Blacklist of words to avoid in the response" of `.github\copilot-instructions.md`: #file:../copilot-instructions.md .

You will find below the list of files: make sure your grouped files total all the files listed. If the list is not present, consider the files from the `a.diff` if present in your context
