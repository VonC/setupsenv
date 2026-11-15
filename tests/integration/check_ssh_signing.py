"""Opt-in Windows executable harness; never touches user keys or repositories.

Run with Python: tests/integration/check_ssh_signing.py
Uses the existing disposable-agent fixture, outside unit-test discovery.
"""
import concurrent.futures
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from test_sshagent import AgentIntegrationTests, ROOT  # noqa: E402


def main():
    fixture = AgentIntegrationTests()
    try:
        fixture.setUp()
        shutil.copy2(ROOT / "bin/ssh-sign.bat", fixture.scripts)
        key = fixture.encrypted_key_with_passphrase_file(b"disposable-test-passphrase\n")
        public = Path(str(key) + ".pub")
        passphrase = Path(str(key) + ".passphrase")
        git = fixture.tools.parents[1] / "cmd/git.exe"
        env = dict(fixture.env, GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        for name in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_CONFIG_COUNT",
                     "GIT_CONFIG_PARAMETERS", "HOME", "PRGS"):
            env.pop(name, None)
        # Exercise Git's key:: path, as used by the station's defaultKeyCommand.
        selector = fixture.folder / "select key.cmd"
        selector.write_text('@echo off\n<nul set /p "=key::"\ntype "' + str(public) + '"\n')
        signers = fixture.folder / "allowed signers"
        signers.write_text("test@example.invalid " + public.read_text())
        repo = fixture.folder / "signing repository"
        repo.mkdir()
        settings = [
            "-c", "user.name=Disposable Test", "-c", "user.email=test@example.invalid",
            "-c", "gpg.format=ssh", "-c", "commit.gpgsign=true",
            "-c", "gpg.ssh.program=" + (fixture.scripts / "ssh-sign.bat").as_posix(),
            "-c", "gpg.ssh.defaultKeyCommand=" + '"' + selector.as_posix() + '"',
            "-c", "gpg.ssh.allowedSignersFile=" + str(signers),
            "-c", "core.hooksPath=" + str(fixture.folder / "no-hooks"),
        ]

        def run(*args, success=True, extra_env=None):
            result = subprocess.run([str(git), *settings, *args], cwd=repo,
                                    env=env | (extra_env or {}), stdin=subprocess.DEVNULL,
                                    capture_output=True, text=True, timeout=45)
            if fixture.state.exists():
                state = json.loads(fixture.state.read_text())
                fixture.agents.add((state["socket"], state["pid"]))
            if success:
                assert result.returncode == 0, result.stdout + result.stderr
            else:
                assert result.returncode != 0, result.stdout + result.stderr
            return result

        run("init", "-q", "--template=")
        run("commit", "--allow-empty", "-m", "Missing agent variables")
        run("verify-commit", "HEAD")
        original = fixture.state.read_bytes()
        print("PASS: signed and verified through Git, no inherited agent or senv variables", flush=True)

        run("commit", "--allow-empty", "-m", "Stale inherited socket",
            extra_env={"SSH_AUTH_SOCK": "/tmp/does-not-exist/agent.0", "SSH_AGENT_PID": "999999"})
        assert fixture.state.read_bytes() == original
        print("PASS: stale caller environment recovered, saved agent reused", flush=True)

        # Removing only our disposable key produces the same state as expiry,
        # without a timing-sensitive sleep or changing the configured lifetime.
        assert fixture.ssh_add("-d", public).returncode == 0
        run("commit", "--allow-empty", "-m", "Reload after expiry")
        run("verify-commit", "HEAD")
        assert fixture.state.read_bytes() == original
        print("PASS: absent key reloaded into the same agent", flush=True)

        assert fixture.ssh_add("-d", public).returncode == 0
        tree = run("rev-parse", "HEAD^{tree}").stdout.strip()
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            commits = list(pool.map(lambda i: run("commit-tree", tree, "-S", "-m", f"Concurrent {i}"), range(2)))
        for result in commits:
            run("verify-commit", result.stdout.strip())
        assert fixture.state.read_bytes() == original
        print("PASS: concurrent signers recover one shared agent", flush=True)

        state = json.loads(original)
        fixture.stop_agent(state["socket"], state["pid"])
        fixture.agents.discard((state["socket"], state["pid"]))
        # Verification must work without a live agent, or even a private key.
        private_bytes = key.read_bytes()
        key.unlink()
        run("verify-commit", "HEAD")
        assert fixture.state.read_bytes() == original
        key.write_bytes(private_bytes)
        run("commit", "--allow-empty", "-m", "Agent restart")
        run("verify-commit", "HEAD")
        assert fixture.state.read_bytes() != original
        print("PASS: verification does not unlock; signing replaces dead agent state", flush=True)

        assert fixture.ssh_add("-d", public).returncode == 0
        before = run("rev-parse", "HEAD").stdout
        passphrase.unlink()
        failure = run("commit", "--allow-empty", "-m", "Must fail without prompt", success=False)
        assert "no private passphrase file" in failure.stderr, failure.stderr
        assert run("rev-parse", "HEAD").stdout == before
        passphrase.write_text("wrong passphrase\n")
        failure = run("commit", "--allow-empty", "-m", "Must fail wrong passphrase", success=False)
        assert "does not unlock the key" in failure.stderr, failure.stderr
        assert run("rev-parse", "HEAD").stdout == before
        passphrase.write_text("disposable-test-passphrase\n")
        run("commit", "--allow-empty", "-m", "Retry after unlock correction")
        print("PASS: missing/wrong passphrase fails promptly, HEAD unchanged; retry works", flush=True)

        run("-c", "user.signingkey=" + str(public),
            "commit", "--allow-empty", "-m", "Explicit public key path")
        run("verify-commit", "HEAD")
        print("PASS: explicit public key paths are supported", flush=True)

        other = fixture.folder / "other key"
        fixture.create_key(other)
        failure = run("-c", "user.signingkey=key::" + Path(str(other) + ".pub").read_text().strip(),
                      "commit", "--allow-empty", "-m", "Must not substitute a key", success=False)
        assert "Couldn't find key in agent" in failure.stderr, failure.stderr
        print("PASS: a different repository signing key is never silently substituted", flush=True)
    finally:
        fixture.doCleanups()


if __name__ == "__main__":
    main()
