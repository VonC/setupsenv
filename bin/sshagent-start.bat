@echo off
rem Optional shell startup: recover without prompting, retain the environment,
rem and never make terminal activation depend on SSH signing availability.
rem No SETLOCAL: sshagent exports the recovered socket into this CMD.
if defined SENV_SSH_AGENT_CONFIG (
    if not exist "%SENV_SSH_AGENT_CONFIG%" exit /b 0
) else (
    if not exist "%LOCALAPPDATA%\senv\ssh-agent.local.json" exit /b 0
)
call "%~dp0sshagent.bat" ensure
if errorlevel 1 echo sshagent: WARNING: SSH key recovery failed; continuing terminal startup. Git signing will retry and still requires the key. 1>&2
exit /b 0
