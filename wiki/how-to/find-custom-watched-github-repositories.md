# How to find the GitHub repositories you watch for releases or security alerts

<img src="../assets/logo-senv-applications-transparent.png" alt="" height="90" align="right">

Goal: list the repositories you follow with a custom watch (releases only,
security alerts...), which GitHub's own watched list leaves out, and narrow
them down to a subject.

`ghwatched` needs a logged-in `gh`: `gh auth status` shows the account. It
only finds the repositories you also starred; see
[why ghwatched looks among your stars](../explanation/why-ghwatched-looks-among-your-stars.md).

## 📋 Steps

1. List every custom watch:

   ```cmd
   ghwatched
   ```

   Each line reads `owner/name | topics | description`. The last line,
   on standard error, gives the count, such as
   `836 custom-watched repositories`. Reading the stars takes a request per
   hundred of them, a few seconds in all.

2. Keep the repositories about a subject by giving words. One is enough for
   a repository to show, and it matches where a word of the name, a topic
   or the description starts with it:

   ```cmd
   ghwatched security vuln
   ghwatched security,vuln
   ```

   `vuln` finds `vulnerability`, but `auth` does not find `oauth`.

3. Ask for a whole word when a short one would catch longer ones: `pip`
   also finds `pipeline`, `=pip` finds only `pip`.

   ```cmd
   ghwatched =pip,=uv,pypi
   ```

4. Use the shipped security word list:

   ```cmd
   ghwatched @security
   ```

5. Keep a list of your own next to the deployed script, for instance
   `%HOME%\bin\ghwatched.python.txt`:

   ```text
   # Python packaging and tooling
   python, =pip, pypi, =uv, poetry
   ```

   then run `ghwatched @python`. A path works as well:
   `ghwatched @C:\lists\go.txt`.

6. Save the names only, without the count:

   ```cmd
   ghwatched -Names @security > security-watches.txt
   ```

## ✅ Check

The count line says how many repositories matched out of how many custom
watches, such as `94 of 836 custom-watched repositories match`. When no
repository matches, the list is empty and `ghwatched` exits 1; the other
codes are in [exit codes](../reference/exit-codes.md#ghwatched).

A repository you know you follow is missing? Star it, then run `ghwatched`
again: a custom watch without a star stays out of its reach.
