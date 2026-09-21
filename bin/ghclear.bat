@echo off
setlocal enabledelayedexpansion

rem ghclear.bat - clear the GitHub notification inbox by marking its threads
rem as done through the GitHub API. Unread threads only, unless 'all' is given.
rem
rem   ghclear        report the unread threads, ask, then mark them done
rem   ghclear all    the same over every thread the API lists, the read and the
rem                  already done ones included
rem   ghclear yes    same, without the question
rem   ghclear read   only mark everything read; the threads stay in the inbox
rem   ghclear dry    report what would happen, change nothing
rem
rem 'done' is what empties the inbox; 'read' only greys the threads out and
rem leaves them there. GitHub has no bulk done endpoint, so done goes thread by
rem thread, one DELETE each, while read is a single PUT for the whole inbox.
rem
rem Unread is the default because the API cannot tell a done thread from a read
rem one, and '?all=true' keeps listing threads long after they were marked done:
rem sweeping all of them means marking the same settled threads done again on
rem every run, and that set only grows. 'all' is the one-off catch-up, for when
rem read threads sitting in the inbox have to go too.
rem
rem Beware: done cannot be undone. A thread marked done comes back only when
rem there is new activity on it, so 'ghclear dry' is there to look first.
rem
rem The token needs the 'notifications' or the 'repo' scope; 'gh auth status'
rem shows the scopes the active account has.
rem
rem The API has no idea what the inbox holds: 'GET /notifications?all=true' keeps
rem handing back threads long after they were marked done, so counting it proves
rem nothing. What the run is judged on instead is the status code of each DELETE
rem plus the count of unread threads left. Read and done do stay apart in the
rem data, mind: marking read stamps last_read_at, marking done only drops the
rem unread flag, so a thread with unread false and no last_read_at is a done one.
rem
rem The lines are counted by walking them rather than with 'find /c /v ""':
rem senv puts the git tools ahead of System32 on PATH, so 'find' there is GNU
rem find, which reads '/c' as a folder to search and walks the whole C: drive.
rem The few externals left are called from System32 by their full path, for the
rem same reason.

for %%i in ("%~dp0.") do set "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do set "senv_dir=%%~fi"
call "%senv_dir%\batcolors\echos_macros.bat"

set "ghclear_dry="
set "ghclear_yes="
set "ghclear_readonly="
set "ghclear_all="
set "ghclear_gh="
set "ghclear_ids=%TEMP%\ghclear.ids.%RANDOM%.txt"
set "ghclear_left=%TEMP%\ghclear.left.%RANDOM%.txt"
set "ghclear_log=%TEMP%\ghclear.log.%RANDOM%.txt"
set "ghclear_ping=%SystemRoot%\System32\ping.exe"
set "ghclear_where=%SystemRoot%\System32\where.exe"

:parse_args
if "%~1"=="" goto:args_parsed
if /I "%~1"=="all" ( set "ghclear_all=1" & shift & goto:parse_args )
if /I "%~1"=="dry" ( set "ghclear_dry=1" & shift & goto:parse_args )
if /I "%~1"=="yes" ( set "ghclear_yes=1" & shift & goto:parse_args )
if /I "%~1"=="read" ( set "ghclear_readonly=1" & shift & goto:parse_args )
%_fatal% "Unknown argument '%~1'; expected 'all', 'dry', 'read' or 'yes'" 41

:args_parsed
rem Left alone by default, and listed only on 'all': the read and the already
rem done threads, which the API hands back either way.
set "ghclear_inbox=/notifications?per_page=100"
if defined ghclear_all set "ghclear_inbox=/notifications?all=true&per_page=100"

call :find_gh
if errorlevel 1 exit /b %ERRORLEVEL%

call :read_inbox
set "ghclear_rc=!ERRORLEVEL!"
if not "!ghclear_rc!"=="0" (
   call :cleanup
   exit /b !ghclear_rc!
)

if defined ghclear_all (
   %_info% "Inbox holds !ghclear_before! thread(s): !ghclear_unread! unread, !ghclear_seen! already read or done"
) else (
   %_info% "!ghclear_before! unread thread(s) to clear"
)

if "!ghclear_before!"=="0" (
   if defined ghclear_all (
      %_ok% "The inbox is already empty; nothing to do"
   ) else (
      %_ok% "Nothing unread; nothing to do. Add 'all' to sweep the read ones too"
   )
   call :cleanup
   exit /b 0
)

set "ghclear_action=marked as done and dropped from the inbox"
if defined ghclear_readonly set "ghclear_action=marked as read, staying in the inbox"

if defined ghclear_dry (
   %_info% "dry: !ghclear_before! thread(s) would be !ghclear_action!"
   call :cleanup
   exit /b 0
)

if defined ghclear_yes goto:confirmed
if not defined ghclear_readonly %_warning% "Marking a thread done cannot be undone"
set "ghclear_answer="
set /p "ghclear_answer=!ghclear_before! thread(s) will be !ghclear_action!. Continue [y/N] ? "
if /I "!ghclear_answer!"=="y" goto:confirmed
%_warning% "Cancelled; the inbox is untouched"
call :cleanup
exit /b 0

:confirmed
if defined ghclear_readonly (
   call :mark_read
) else (
   call :mark_done
)
set "ghclear_rc=!ERRORLEVEL!"
call :cleanup
exit /b !ghclear_rc!


rem Sets ghclear_gh to the gh.exe to drive, the senv one first, one on PATH
rem otherwise, and makes sure it holds a usable login.
:find_gh
set "ghclear_gh=%PRGS%\ghs\gh-cli\bin\gh.exe"
if exist "%ghclear_gh%" goto:gh_found
set "ghclear_gh="
for /f "usebackq delims=" %%g in (`"%ghclear_where%" gh.exe 2^>NUL`) do if not defined ghclear_gh set "ghclear_gh=%%g"
if not defined ghclear_gh (
   %_fatal% "No gh.exe found, neither '%PRGS%\ghs\gh-cli\bin\gh.exe' nor one on PATH" 42
)
:gh_found
"%ghclear_gh%" auth status >NUL 2>&1
if errorlevel 1 (
   %_fatal% "gh is not logged in; run 'gh auth login' first" 43
)
exit /b 0

rem Writes one '<unread>\t<thread id>' line per inbox thread into ghclear_ids,
rem and counts them into ghclear_before / ghclear_unread / ghclear_seen.
:read_inbox
%_task% "Must read the notification inbox"
"%ghclear_gh%" api --paginate "%ghclear_inbox%" -q ".[] | [.unread, .id] | @tsv" > "%ghclear_ids%" 2>"%ghclear_log%"
if errorlevel 1 (
   %_error% "Unable to read the notifications"
   type "%ghclear_log%"
   exit /b 44
)
set "ghclear_before=0"
set "ghclear_unread=0"
for /f "usebackq tokens=1,2" %%u in ("%ghclear_ids%") do (
   set /a "ghclear_before+=1"
   if "%%u"=="true" set /a "ghclear_unread+=1"
)
set /a "ghclear_seen=!ghclear_before! - !ghclear_unread!"
exit /b 0

rem One PUT for the whole inbox. last_read_at is left out on purpose: the API
rem defaults it to the current timestamp, which is exactly what is wanted, and
rem anything arriving later stays unread.
:mark_read
%_task% "Must mark the whole inbox as read"
"%ghclear_gh%" api -X PUT /notifications --silent >NUL 2>"%ghclear_log%"
if errorlevel 1 (
   %_error% "Unable to mark the notifications as read"
   type "%ghclear_log%"
   exit /b 45
)
%_ok% "!ghclear_unread! thread(s) marked as read; they stay in the inbox"
exit /b 0

rem One DELETE per thread, there being no bulk done endpoint. GitHub counts a
rem DELETE as 5 points against a 900 points per minute budget, so the pace has
rem to stay under 180 calls a minute: gh.exe spends about half a second on each
rem call by itself, and the breather every 25 keeps a margin on top of that.
:mark_done
%_task% "Must mark !ghclear_before! thread(s) as done"
set "ghclear_done=0"
set "ghclear_failed=0"
set "ghclear_count=0"
for /f "usebackq tokens=1,2" %%u in ("%ghclear_ids%") do (
   "%ghclear_gh%" api -X DELETE "/notifications/threads/%%v" --silent >NUL 2>>"%ghclear_log%"
   if errorlevel 1 ( set /a "ghclear_failed+=1" ) else ( set /a "ghclear_done+=1" )
   set /a "ghclear_count+=1"
   set /a "ghclear_rest=!ghclear_count! %% 25"
   if !ghclear_rest! EQU 0 (
      echo    !ghclear_count! / !ghclear_before! threads, !ghclear_failed! failed
      "%ghclear_ping%" -n 2 127.0.0.1 >NUL
   )
)

rem Left out of this count on purpose: the inbox itself, which no endpoint
rem reports. A thread stays in '?all=true' once it is done, so the only honest
rem checks are that every DELETE came back happy and that nothing is unread.
%_task% "Must check nothing was left behind"
"%ghclear_gh%" api --paginate "/notifications?per_page=100" -q ".[].id" > "%ghclear_left%" 2>NUL
set "ghclear_unread_left=0"
for /f "usebackq delims=" %%i in ("%ghclear_left%") do set /a "ghclear_unread_left+=1"

if not "!ghclear_failed!"=="0" (
   %_error% "!ghclear_failed! thread(s) could not be marked done; the API said:"
   type "%ghclear_log%"
   %_warning% "!ghclear_done! of !ghclear_before! thread(s) marked done; run ghclear again"
   exit /b 46
)
if not "!ghclear_unread_left!"=="0" (
   %_warning% "!ghclear_done! thread(s) marked done, and !ghclear_unread_left! unread one(s) landed since; run ghclear again"
   exit /b 46
)
%_ok% "Inbox cleared: !ghclear_done! of !ghclear_before! thread(s) marked done, none failed, nothing unread left"
exit /b 0

:cleanup
if exist "%ghclear_ids%" del /Q "%ghclear_ids%" >NUL 2>&1
if exist "%ghclear_left%" del /Q "%ghclear_left%" >NUL 2>&1
if exist "%ghclear_log%" del /Q "%ghclear_log%" >NUL 2>&1
goto:eof

:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
