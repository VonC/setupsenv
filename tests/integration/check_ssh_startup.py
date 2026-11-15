"""Opt-in Windows check of tuitp pane startup with disposable SSH credentials.

Run: python tests/integration/check_ssh_startup.py
Runs the real pane/helper scripts with fixture senv and agent commands; opens
no terminals or LLM sessions and never changes the user's keys or config.
"""
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
        shutil.copy2(ROOT / "bin/sshagent-start.bat", fixture.scripts)
        key = fixture.encrypted_key_with_passphrase_file(b"disposable-test-passphrase\n")
        public = Path(str(key) + ".pub")
        passphrase = Path(str(key) + ".passphrase")
        profile = fixture.folder / "profile"
        project = fixture.folder / "project"
        profile.mkdir()
        project.mkdir()
        startup = fixture.scripts / "sshagent-start.bat"
        (profile / "senv.bat").write_text(
            '@echo off\nif /i "%~1"=="aliases" exit /b 0\n'
            f'call "{startup}"\n', encoding="utf-8")
        (project / "senv.bat").write_text(
            '@echo off\nif /i "%ACTIVATION%"=="local-or-global" '
            f'call "{startup}"\n', encoding="utf-8")
        for role in ("claude", "codex"):
            (fixture.scripts / (role + ".bat")).write_text(
                f'@echo off\necho STARTED={role}\n'
                'echo TEST_SOCKET=%SSH_AUTH_SOCK%\nexit /b 0\n', encoding="utf-8")
        runner = fixture.folder / "run-pane.cmd"
        runner.write_text(
            '@echo off\n'
            f'call "{ROOT / "bin/tuitp.pane.bat"}" "{project}" %ROLE% %ACTIVATION%\n'
            'exit /b %errorlevel%\n', encoding="utf-8")
        env = dict(fixture.env, USERPROFILE=str(profile), LOCALAPPDATA=str(profile),
                   PRGS=str(fixture.folder), PATH=str(fixture.scripts) + os.pathsep + os.environ["PATH"])
        for name in list(env):
            if name.upper().startswith("TUITP_"):
                del env[name]
        signal = fixture.folder / "activation.done"

        def pane(role="claude", activation="project", **extra):
            result = subprocess.run(
                ["cmd.exe", "/d", "/v:off", "/c", str(runner)],
                env=env | dict(ROLE=role, ACTIVATION=activation,
                               TUITP_SENV_SIGNAL=str(signal)) | extra,
                stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=45)
            if fixture.state.exists():
                state = json.loads(fixture.state.read_text(encoding="utf-8-sig"))
                fixture.agents.add((state["socket"], state["pid"]))
            return result

        def launched(result, role="claude", recovered=True):
            assert result.returncode == 0, result.stdout + result.stderr
            assert f"STARTED={role}" in result.stdout, result.stdout + result.stderr
            assert signal.read_text().strip() == "0"
            if recovered:
                state = json.loads(fixture.state.read_text(encoding="utf-8-sig"))
                assert "TEST_SOCKET=" + state["socket"] in result.stdout, result.stdout
                assert "ERROR" not in result.stderr, result.stderr

        launched(pane())
        original = fixture.state.read_bytes()
        print("PASS: fresh agent recovered before Claude starts; socket inherited", flush=True)

        assert fixture.ssh_add("-d", public).returncode == 0
        expired = fixture.run_launcher("status")
        assert expired.returncode != 0 and "is not loaded" in expired.stderr
        launched(pane("codex", "local-or-global",
                      SSH_AUTH_SOCK="/tmp/stale/agent.0", SSH_AGENT_PID="999999"), "codex")
        assert fixture.state.read_bytes() == original
        assert fixture.ssh_add("-L").returncode == 0
        print("PASS: expired key and stale environment recovered before Codex starts", flush=True)

        assert fixture.ssh_add("-d", public).returncode == 0
        passphrase.unlink()
        result = pane()
        launched(result, recovered=False)
        assert "continuing terminal startup" in result.stderr, result.stderr
        assert fixture.run_launcher("ensure").returncode != 0
        print("PASS: unavailable passphrase does not block pane; signing recovery stays strict", flush=True)

        fixture.config.write_text("invalid JSON", encoding="utf-8")
        result = pane("codex", "local-or-global")
        launched(result, "codex", recovered=False)
        assert "continuing terminal startup" in result.stderr, result.stderr
        fixture.config.unlink()
        result = pane()
        launched(result, recovered=False)
        assert "sshagent:" not in result.stdout + result.stderr
        print("PASS: invalid config is nonfatal; unconfigured stations skip SSH startup", flush=True)

        (project / "senv.bat").write_text("@echo off\nexit /b 23\n", encoding="utf-8")
        result = pane()
        assert result.returncode == 23, result.stdout + result.stderr
        assert "STARTED=" not in result.stdout
        assert signal.read_text().strip() == "23"
        print("PASS: unrelated project activation failures still stop pane launch", flush=True)
    finally:
        fixture.doCleanups()


if __name__ == "__main__":
    main()
