@echo off
setlocal EnableExtensions DisableDelayedExpansion
rem Git's gpg.ssh.program: recover the agent at signing time, even in an old
rem application with missing/stale SSH_AUTH_SOCK or after the key expires.
rem Verification delegates without loading a private key. Keep stdout reserved
rem for ssh-keygen's protocol; diagnostics from preparation go to stderr.
set "_senv_sign_mode=tool"
if "%~1"=="-Y" if "%~2"=="sign" set "_senv_sign_mode=ensure"
call "%~dp0sshagent.bat" %_senv_sign_mode% 1>&2
if errorlevel 1 exit /b %errorlevel%
"%SENV_SSH_KEYGEN%" %*
exit /b %errorlevel%
