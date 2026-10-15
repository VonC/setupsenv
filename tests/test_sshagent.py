"""Windows integration tests using disposable keys and real Git SSH agents.

Run: python -m unittest discover -s tests -p test_sshagent.py -v
No user keys, Git configuration, Windows services or existing agents are changed.
"""
import concurrent.futures
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest
import uuid


ROOT = Path(__file__).resolve().parents[1]
GIT_BIN = Path(os.environ.get(
    "SENV_TEST_GIT_BIN",
    str(Path(os.environ.get("PRGS", "C:/Program Files")) / "gits/current/usr/bin"),
))


@unittest.skipUnless(os.name == "nt" and (GIT_BIN / "ssh-agent.exe").exists(),
                     "Requires Windows and Git SSH tools (SENV_TEST_GIT_BIN)")
class AgentIntegrationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="senv-agent-test-")
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.tools = GIT_BIN.resolve()
        self.env = dict(os.environ)
        for name in ("SSH_AUTH_SOCK", "SSH_AGENT_PID", "SSH_ASKPASS", "DISPLAY"):
            self.env.pop(name, None)
        self.env["SSH_ASKPASS_REQUIRE"] = "force"
        # Never allow a test to wait for a human passphrase.
        self.askpass = self.folder / "askpass.sh"
        self.askpass.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
        self.env["SSH_ASKPASS"] = self.askpass.as_posix()
        self.config = self.folder / "private config.json"
        self.state = Path(str(self.config) + ".state.json")
        self.env["SENV_SSH_AGENT_CONFIG"] = str(self.config)
        self.key = self.folder / "disposable key"
        self.create_key(self.key)
        self.write_config()
        self.agents = set()
        self.addCleanup(self.stop_agents)
        self.scripts = self.folder / "scripts with spaces"
        self.scripts.mkdir()
        for name in ("sshagent.bat", "sshagent.ps1"):
            shutil.copy2(ROOT / "bin" / name, self.scripts / name)

    def create_key(self, path, passphrase=""):
        result = subprocess.run([
            str(self.tools / "ssh-keygen.exe"), "-q", "-t", "ed25519",
            "-N", passphrase, "-C", "disposable-test", "-f", str(path),
        ], env=self.env, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)

    def write_config(self, **overrides):
        config = dict(privateKey=str(self.key), gitBin=str(GIT_BIN), lifetimeSeconds=300)
        config.update(overrides)
        self.config.write_text(json.dumps(config), encoding="utf-8")

    def run_launcher(self, mode="load", env=None):
        runner = self.folder / (str(uuid.uuid4()) + ".cmd")
        runner.write_text(
            '@echo off\ncall "' + str(self.scripts / "sshagent.bat") + '" ' + mode + '\n'
            'set "_test_rc=%errorlevel%"\n'
            'if defined SSH_AUTH_SOCK echo TEST_SOCKET=%SSH_AUTH_SOCK%\n'
            'if defined SSH_AGENT_PID echo TEST_PID=%SSH_AGENT_PID%\n'
            'exit /b %_test_rc%\n', encoding="utf-8")
        result = subprocess.run(["cmd.exe", "/d", "/c", str(runner)],
                                env=env or self.env, stdin=subprocess.DEVNULL,
                                capture_output=True, text=True, timeout=45)
        if self.state.exists():
            try:
                state = json.loads(self.state.read_text(encoding="utf-8-sig"))
                self.agents.add((state["socket"], state["pid"]))
            except (ValueError, KeyError):
                pass
        return result

    def agent_env(self):
        state = json.loads(self.state.read_text(encoding="utf-8-sig"))
        return dict(self.env, SSH_AUTH_SOCK=state["socket"], SSH_AGENT_PID=state["pid"])

    def ssh_add(self, *args):
        return subprocess.run([str(self.tools / "ssh-add.exe"), *map(str, args)],
                              env=self.agent_env(), capture_output=True, text=True, timeout=15)

    def stop_agent(self, socket, pid):
        subprocess.run([str(self.tools / "ssh-agent.exe"), "-k"],
                       env=dict(self.env, SSH_AUTH_SOCK=socket, SSH_AGENT_PID=pid),
                       capture_output=True, timeout=15)

    def stop_agents(self):
        for socket, pid in self.agents:
            self.stop_agent(socket, pid)

    def assert_success(self, result):
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        state = json.loads(self.state.read_text(encoding="utf-8-sig"))
        self.assertIn("TEST_SOCKET=" + state["socket"], result.stdout)
        self.assertIn("TEST_PID=" + state["pid"], result.stdout)

    def test_start_reuse_and_status_export_to_cmd(self):
        self.assert_success(self.run_launcher())
        original = self.state.read_bytes()
        self.assert_success(self.run_launcher())
        self.assertEqual(self.state.read_bytes(), original)
        timestamp = self.state.stat().st_mtime_ns
        self.assert_success(self.run_launcher("status"))
        self.assertEqual(self.state.stat().st_mtime_ns, timestamp)

    def test_status_does_not_start_agent(self):
        result = self.run_launcher("status")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("No reachable agent", result.stderr)
        self.assertFalse(self.state.exists())

    def test_missing_or_invalid_config_does_not_start_agent(self):
        self.config.unlink()
        self.assertNotEqual(self.run_launcher().returncode, 0)
        self.config.write_text("invalid JSON", encoding="utf-8")
        self.assertNotEqual(self.run_launcher().returncode, 0)
        self.write_config(lifetimeSeconds=0)
        self.assertNotEqual(self.run_launcher().returncode, 0)
        self.write_config(privateKey=str(self.key) + ".pub")
        self.assertNotEqual(self.run_launcher().returncode, 0)
        self.assertFalse(self.state.exists())

    def test_empty_or_wrong_key_agent_is_reused_and_other_keys_preserved(self):
        self.assert_success(self.run_launcher())
        original = self.state.read_bytes()
        self.assertEqual(self.ssh_add("-d", str(self.key) + ".pub").returncode, 0)
        self.assertNotEqual(self.run_launcher("status").returncode, 0)
        other = self.folder / "other key"
        self.create_key(other)
        self.assertEqual(self.ssh_add(other).returncode, 0)
        self.assertNotEqual(self.run_launcher("status").returncode, 0)
        self.assert_success(self.run_launcher())
        self.assertEqual(self.state.read_bytes(), original)
        self.assertEqual(len(self.ssh_add("-L").stdout.strip().splitlines()), 2)

    def test_stale_state_after_agent_exit(self):
        self.assert_success(self.run_launcher())
        original = json.loads(self.state.read_text())
        self.stop_agent(original["socket"], original["pid"])
        self.agents.discard((original["socket"], original["pid"]))
        self.assertNotEqual(self.run_launcher("status").returncode, 0)
        self.assert_success(self.run_launcher())
        self.assertNotEqual(json.loads(self.state.read_text())["socket"], original["socket"])

    def test_inherited_agent_is_adopted_when_saved_state_is_missing(self):
        self.assert_success(self.run_launcher())
        env = self.agent_env()
        original = self.state.read_bytes()
        self.state.unlink()
        self.assert_success(self.run_launcher(env=env))
        self.assertEqual(self.state.read_bytes(), original)

    def test_malformed_state_is_recoverable(self):
        self.state.write_text("{broken", encoding="utf-8")
        self.assert_success(self.run_launcher())

    def test_public_key_mismatch_is_reported(self):
        original_public = Path(str(self.key) + ".pub").read_bytes()
        other = self.folder / "other key"
        self.create_key(other)
        shutil.copyfile(str(other) + ".pub", str(self.key) + ".pub")
        result = self.run_launcher()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not match", result.stderr)
        original_state = self.state.read_bytes()
        Path(str(self.key) + ".pub").write_bytes(original_public)
        self.assert_success(self.run_launcher())
        self.assertEqual(self.state.read_bytes(), original_state)

    def test_encrypted_key_cancel_and_retry(self):
        encrypted = self.folder / "encrypted key"
        self.create_key(encrypted, "disposable-test-passphrase")
        self.write_config(privateKey=str(encrypted))
        result = self.run_launcher()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("failed or was cancelled", result.stderr)
        original = self.state.read_bytes()
        self.askpass.write_text("#!/bin/sh\nprintf '%s\\n' 'disposable-test-passphrase'\n", encoding="utf-8")
        self.assert_success(self.run_launcher())
        self.assertEqual(self.state.read_bytes(), original)
        # Disable the fixture prompt: an already loaded key must not prompt again.
        self.askpass.write_text("#!/bin/sh\nexit 1\n", encoding="utf-8")
        self.assert_success(self.run_launcher())

    def test_concurrent_calls_share_one_agent(self):
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(lambda _: self.run_launcher(), range(2)))
        for result in results:
            self.assert_success(result)
        self.assertEqual(len(self.agents), 1)
        self.assertEqual(sum("started a user agent" in r.stdout for r in results), 1)

    def test_exported_agent_can_sign_and_verify_a_git_commit(self):
        self.assert_success(self.run_launcher())
        env = self.agent_env()
        env.update(GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL=os.devnull)
        for name in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_CONFIG_COUNT"):
            env.pop(name, None)
        repository = self.folder / "signing repository"
        repository.mkdir()
        git = self.tools.parents[1] / "cmd/git.exe"
        signers = self.folder / "allowed signers"
        signers.write_text("test@example.invalid " + Path(str(self.key) + ".pub").read_text(), encoding="utf-8")
        commands = [
            ["init", "-q", "--template="],
            ["-c", "user.name=Disposable Test", "-c", "user.email=test@example.invalid",
             "-c", "gpg.format=ssh", "-c", "commit.gpgsign=true",
             "-c", "user.signingkey=" + str(self.key) + ".pub",
             "-c", "core.hooksPath=" + str(self.folder / "no-hooks"),
             "commit", "-q", "--allow-empty", "-m", "Test agent signing"],
            ["-c", "gpg.ssh.allowedSignersFile=" + str(signers), "verify-commit", "HEAD"],
        ]
        for args in commands:
            result = subprocess.run([str(git), *args], cwd=repository, env=env,
                                    stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=15)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
