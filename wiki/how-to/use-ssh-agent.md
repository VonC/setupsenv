# Load an SSH signing key without administrator rights

Run `sshagent` in CMD to start or reuse Git for Windows' user SSH agent and
load this station's private key. No Windows service is required. Enter the
passphrase in the local prompt, or keep it in a private file next to the
key (see [skip the passphrase prompt](#skip-the-passphrase-prompt)). The
matching `.pub` file identifies the key, but the **private key** is loaded
into the agent.

## Configure each station once

`setup.bat` deploys `sshagent.bat`, its PowerShell helper, `sshagent-start.bat`, `ssh-sign.bat` and
the example to `%HOME%\bin`. In an existing installation, copy those files from
`%PRGS%\senv\bin` to `%HOME%\bin`.

```cmd
if not exist "%LOCALAPPDATA%\senv" mkdir "%LOCALAPPDATA%\senv"
copy /-Y "%HOME%\bin\sshagent.example.json" "%LOCALAPPDATA%\senv\ssh-agent.local.json"
notepad "%LOCALAPPDATA%\senv\ssh-agent.local.json"
```

Set `privateKey` to the private key's absolute Windows path. The adjacent
`<privateKey>.pub` must exist. JSON backslashes need doubling; environment
variables such as `%HOME%` and `%PRGS%` are expanded when the command runs.
`gitBin` is optional and defaults to `%PRGS%\gits\current\usr\bin`.
An senv session already includes that directory on `PATH`; keep this field
only to make the location explicit or select a different Git installation.
The helper uses the selected directory for all three SSH tools, avoiding a
mix with Windows' service-based OpenSSH tools. It resolves junctions such
as `current` to the real installation because Windows can reject starting
`ssh-agent.exe` through a junction as an untrusted mount point.
`lifetimeSeconds` defaults to 3600 (one hour) and must be a positive integer.
For example, 36000 means ten hours. Changing it affects future key loads;
an already loaded key keeps its existing expiry time.

For applications launched outside senv, use literal absolute paths for
`privateKey` and `gitBin`. Such applications may not inherit `HOME` or `PRGS`.

Keep this config and the generated `.state.json` file beside it local to
the computer, outside repositories and synchronized folders. Do not put
the private key or passphrase in the config. If your keys are inside a Git
working tree, exclude them locally using `.git/info/exclude`.

## Skip the passphrase prompt

The private key is stored encrypted, so loading it into the agent needs
its passphrase once per agent lifetime. To load it without a prompt, put
the passphrase on the first line of a file named after the private key,
with `.passphrase` appended:

```cmd
notepad "%HOME%\.ssh\id_signing.passphrase"
```

`sshagent` then reads that line instead of prompting. A wrong passphrase
stops the command with an error naming the file, with no retry; correct
the file or delete it to be prompted again.

Anyone who can read that file can use the key, as if it had no passphrase
at all. Keep it on this computer only, outside synchronized folders. When
it sits inside a Git working tree, `sshagent` refuses it until that
repository ignores it, for example with a `*.passphrase` line in
`.git/info/exclude`.

## Recover the agent automatically when Git signs

Loading a key before starting an LLM does not cover key expiry, an agent
exit, or tools launched with missing or stale environment variables. Configure
Git to recover the agent when it actually signs a commit or tag:

```cmd
git config --global gpg.ssh.program "%HOME%/bin/ssh-sign.bat"
```

Run that command once in an senv CMD, where `HOME` names the installation.
Git saves the expanded path. This applies to both already-running and new
applications using this Git configuration, including direct `git commit` and
`gcba` from CMD or PowerShell. Repository or command-line overrides still take
precedence. Existing SSH signing settings, key selection, and allowed signers
stay in effect; a different key selected by a repository must also be loaded.

The wrapper uses `sshagent ensure` to reconnect to the saved agent, start one
when needed, and reload the configured key after expiry. It uses the existing
private `.passphrase` file for unlocking. It never prompts inside a signing
operation: if the key is absent and that file is unavailable, it fails with an
instruction to run `sshagent load` interactively. A wrong passphrase fails
without retrying. Already-loaded keys keep their expiry time.

The SSH executable comes from `gitBin`, so signing uses the same Git for
Windows tools as the agent even when another SSH installation comes first
on `PATH`. Verification resolves that executable without accessing a private
key or starting an agent. Preparation messages go to stderr; signing input,
output and exit status belong to `ssh-keygen`.

This provides the agent environment to Git's signing process. It cannot
change an already-running parent shell, and it does not configure SSH
connections or Git's transport for fetch/push. For those commands, use the
CMD instructions below, or import the agent environment into the process
that launches them.

To return to Git's default SSH signing executable:

```cmd
git config --global --unset gpg.ssh.program
```

If you previously configured a custom signer, restore its value instead.

## Use it in each CMD session

For automatic recovery when senv starts (including tuitp panes), add this
optional hook to `%HOME%\bin\senv.local.bat`:

```cmd
if exist "%~dp0sshagent-start.bat" call "%~dp0sshagent-start.bat"
```

The startup helper skips stations without an agent config. Otherwise it uses
`sshagent ensure` to recover the agent and reload an expired key from the
existing private passphrase file, without prompting. It imports the recovered
agent environment into the shell. A recovery failure is reported but returns
success to shell activation, so Claude, Codex and CMD panes can still start.
Git signing remains strict and retries recovery when a signature is needed.

Replace any startup hook that calls `sshagent status`: that command only
checks the key and returns an error after expiry; it cannot recover it.
Keep `status` for explicit diagnostics.

```cmd
call "%HOME%\bin\sshagent.bat"
```

Or, with `%HOME%\bin` on `PATH`, run `sshagent`. The routine exports
`SSH_AUTH_SOCK` and `SSH_AGENT_PID` into the current CMD environment.
Subsequent commands, including Git, inherit them. Use `call` from another
batch script; running it in a child CMD or from PowerShell cannot update
the parent shell's environment. After loading the key, start applications
that need the agent from this CMD so they inherit its environment too.

```cmd
sshagent status
```

`status` checks without starting an agent, adding a key, or changing saved
state. Success means the configured key is loaded, and imports the agent
environment into CMD. An unavailable agent or missing key returns nonzero.

Normal invocation first tries the saved agent, then an agent inherited
from the caller, then starts a new one. Stale state after reboot is replaced
automatically; no existing agents are killed. Concurrent calls using the
same config are serialized. A key already loaded is left alone, including
its current expiry time; run `sshagent` again after expiry to unlock it.
The signing wrapper performs that recovery automatically at signing time.
Cancelled or failed prompts return nonzero; retrying reuses the saved agent.

For a separate configuration, set `SENV_SSH_AGENT_CONFIG` to its absolute
path before invoking the command. The default is
`%LOCALAPPDATA%\senv\ssh-agent.local.json`. The helper uses Windows
PowerShell 5.1 with a per-process `RemoteSigned` execution policy and
respects enforced organization policies.

This command manages key loading and the agent environment. Git's SSH
signing configuration and the account's registered signing public key
are configured separately. Use Git for Windows' SSH tools with this agent;
Windows' service-based OpenSSH tools use a different agent transport.
