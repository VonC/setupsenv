@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Run with CALL from another batch file so the agent environment is retained.
set "_senv_agent_mode=%~1"
if not defined _senv_agent_mode set "_senv_agent_mode=load"
if /i "%_senv_agent_mode%"=="help" goto :usage
if /i "%_senv_agent_mode%"=="--help" goto :usage
if /i not "%_senv_agent_mode%"=="load" if /i not "%_senv_agent_mode%"=="status" goto :badusage
if not "%~2"=="" goto :badusage
set "_senv_agent_config=%SENV_SSH_AGENT_CONFIG%"
if not defined _senv_agent_config set "_senv_agent_config=%LOCALAPPDATA%\senv\ssh-agent.local.json"
set "_senv_agent_output=%TEMP%\senv-sshagent-%RANDOM%-%RANDOM%.tmp"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy RemoteSigned -File "%~dp0sshagent.ps1" -Mode "%_senv_agent_mode%" -ConfigPath "%_senv_agent_config%" -OutputPath "%_senv_agent_output%"
set "_senv_agent_rc=%errorlevel%"
if not "%_senv_agent_rc%"=="0" goto :failed
set "_senv_agent_sock="
set "_senv_agent_pid="
for /f "usebackq tokens=1,* delims==" %%A in ("%_senv_agent_output%") do (
    if "%%A"=="SSH_AUTH_SOCK" set "_senv_agent_sock=%%B"
    if "%%A"=="SSH_AGENT_PID" set "_senv_agent_pid=%%B"
)
del /q "%_senv_agent_output%" >nul 2>&1
if not defined _senv_agent_sock (echo ERROR: No agent environment was returned. & exit /b 1)
endlocal & set "SSH_AUTH_SOCK=%_senv_agent_sock%" & set "SSH_AGENT_PID=%_senv_agent_pid%" & exit /b 0

:failed
if exist "%_senv_agent_output%" del /q "%_senv_agent_output%" >nul 2>&1
exit /b %_senv_agent_rc%

:badusage
echo ERROR: Unknown argument.
call :usage
exit /b 2

:usage
echo Usage: sshagent [load^|status]
echo   load    Start or reuse a user SSH agent and load the configured private key.
echo   status  Check the agent and key without starting an agent or prompting.
echo Config: %%LOCALAPPDATA%%\senv\ssh-agent.local.json
echo Override: SENV_SSH_AGENT_CONFIG
exit /b 0
