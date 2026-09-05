@echo off
setlocal enabledelayedexpansion

rem wtp.bat - open the Windows Terminal windows described by wtp.list, each tab
rem sitting in its own folder with the global senv.bat and then the local
rem senv.bat already run.
rem
rem   wtp            the missing project tabs plus the startup tab
rem   wtp nostartup  only the project windows
rem   wtp notabs     only the startup tab
rem   wtp force      open every tab again, the open ones included
rem   wtp dry        print the wt.exe command lines, open nothing
rem
rem wtp.list sits next to this script and holds one project per line: a folder
rem path, optionally followed by '|' and the tab title. A line with no title
rem opens a tab whose title is left to the application running in it, so a tool
rem that names its own tab keeps control of it. A line starting with '---'
rem closes the window gathered so far and starts a new one; whatever follows the
rem dashes names that window. Lines starting with '#' and blank lines are
rem ignored. wtp.list is yours to write: wtp.list.example, shipped next to this
rem script, is the pattern to copy and edit.
rem
rem Two optional pieces, both absent by default:
rem
rem - WTP_PROFILE names the Windows Terminal profile the tabs open with. Without
rem   it the tabs open with the profile of the current window.
rem - a startup.bat next to this script gets a tab of its own, added to the
rem   window wtp was called from, for whatever has to run once per session.
rem
rem Each project tab goes through wtp.tab.bat and the startup tab through
rem wtp.startup.bat, because a fresh cmd has no HOME nor PRGS yet while both
rem 'senv.bat all' and startup.bat need them.
rem
rem Running wtp twice opens nothing the second time. Each project tab is started
rem as 'cmd.exe /k wtp.tab.bat <slot>', so the slot it fills stays readable in
rem the command line of the cmd.exe holding the tab, for as long as that tab
rem lives. wtp reads the command line of every live cmd.exe once, skips the
rem slots already answering, and hands the rest to the window their block names,
rem so a tab closed by hand comes back on its own, where it was. Nothing is
rem written to disk and nothing has to be cleaned up: closing a tab retires its
rem marker with it.

for %%i in ("%~dp0.") do set "script_dir=%%~fi"
for %%i in ("%script_dir%\..") do set "senv_dir=%%~fi"
call "%senv_dir%\batcolors\echos_macros.bat"

set "wtp_list=%script_dir%\wtp.list"
set "wtp_example=%script_dir%\wtp.list.example"
set "wtp_tab=%script_dir%\wtp.tab.bat"
set "wtp_startup=%script_dir%\wtp.startup.bat"
set "wtp_startup_run=%script_dir%\startup.bat"
set "wtp_senv=%USERPROFILE%\senv.bat"
set "wtp_snapshot=%TEMP%\wtp.tabs.%RANDOM%.txt"
set "wtp_dry="
set "wtp_force="
set "wtp_notabs="
set "wtp_nostartup="

rem A profile is named only when WTP_PROFILE asks for one, so wtp works on a
rem Windows Terminal with nothing configured in it.
set "wtp_p="
if defined WTP_PROFILE set "wtp_p=-p "%WTP_PROFILE%""

:parse_args
if "%~1"=="" goto:args_parsed
if /I "%~1"=="dry" ( set "wtp_dry=1" & shift & goto:parse_args )
if /I "%~1"=="force" ( set "wtp_force=1" & shift & goto:parse_args )
if /I "%~1"=="notabs" ( set "wtp_notabs=1" & shift & goto:parse_args )
if /I "%~1"=="nostartup" ( set "wtp_nostartup=1" & shift & goto:parse_args )
%_fatal% "Unknown argument '%~1'; expected 'dry', 'force', 'notabs' or 'nostartup'" 51

:args_parsed
if defined wtp_notabs if defined wtp_nostartup (
   %_fatal% "'notabs' and 'nostartup' together leave nothing to open" 52
)

rem senv rebuilds PATH without the WindowsApps folder, so wt.exe has to be
rem reached through its full path.
set "wtp_exe=%LOCALAPPDATA%\Microsoft\WindowsApps\wt.exe"
if not exist "%wtp_exe%" (
   for /f "delims=" %%x in ('where wt.exe 2^>NUL') do set "wtp_exe=%%x"
)
if not exist "%wtp_exe%" (
   %_fatal% "Windows Terminal is not reachable: no 'wt.exe' found" 53
)

if not exist "%wtp_senv%" (
   %_fatal% "Missing senv launcher: '%wtp_senv%'" 54
)
rem Both launchers travel unquoted inside the tab command line, where a space
rem would split them in two.
if not "%wtp_tab%"=="%wtp_tab: =%" (
   %_fatal% "The tab launcher path must not hold a space: '%wtp_tab%'" 55
)
if not "%wtp_startup%"=="%wtp_startup: =%" (
   %_fatal% "The startup launcher path must not hold a space: '%wtp_startup%'" 56
)

call :take_snapshot
if not defined wtp_nostartup call :open_startup_tab
if not defined wtp_notabs call :open_project_windows
set "wtp_rc=%errorlevel%"
if exist "%wtp_snapshot%" del "%wtp_snapshot%" >NUL 2>&1
exit /b %wtp_rc%


rem Lists the command line of every live cmd.exe, which is where the slot of an
rem open tab is written. Only CIM can report a command line now that wmic is
rem gone from Windows, so this is the one PowerShell call wtp makes, and 'force'
rem is what skips it.
:take_snapshot
if defined wtp_force exit /b 0
set "wtp_ps=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%wtp_ps%" (
   for /f "delims=" %%x in ('where powershell.exe 2^>NUL') do set "wtp_ps=%%x"
)
if not exist "%wtp_ps%" (
   %_fatal% "No powershell.exe to read the open tabs with; 'wtp force' opens them blind" 62
)
"%wtp_ps%" -NoProfile -NonInteractive -Command "Get-CimInstance Win32_Process -Filter 'Name=''cmd.exe''' | ForEach-Object { $_.CommandLine }" > "%wtp_snapshot%" 2>NUL
if not exist "%wtp_snapshot%" (
   %_fatal% "Unable to read the open tabs; 'wtp force' opens them blind" 63
)
exit /b 0


rem Sets wtp_found when a live cmd.exe was started with the tail %1, which is a
rem launcher path for the startup tab and a launcher path plus a slot for a
rem project tab.
:tab_is_open
set "wtp_found="
if defined wtp_force exit /b 0
findstr /L /C:"%~1" "%wtp_snapshot%" >NUL 2>&1
if not errorlevel 1 set "wtp_found=1"
exit /b 0


rem Adds the startup.bat tab to the window wtp was launched from. It goes first,
rem while the current window is still the one Windows Terminal calls '0'. Its
rem launcher is its own marker, since no other tab runs wtp.startup.bat. The
rem whole step is optional: without a startup.bat next to this script there is
rem nothing to run, and only a call that asked for that tab alone says so.
:open_startup_tab
if not exist "%wtp_startup_run%" (
   if defined wtp_notabs (
      %_warning% "No startup script '%wtp_startup_run%': nothing to open"
   )
   exit /b 0
)
if not exist "%wtp_startup%" (
   %_fatal% "Missing startup launcher: '%wtp_startup%'" 57
)
call :tab_is_open "%wtp_startup%"
if defined wtp_found (
   %_ok% "the startup tab is already open"
   exit /b 0
)
set "wtp_cmd=-w 0 new-tab --suppressApplicationTitle --title startup %wtp_p% -d "%senv_dir%" cmd.exe /k %wtp_startup%"
if defined wtp_dry (
   %_info% "dry: "%wtp_exe%" %wtp_cmd%"
   exit /b 0
)
%_task% "Must add the startup tab to the current window"
start "" "%wtp_exe%" %wtp_cmd%
if errorlevel 1 (
   %_error% "Unable to add the startup tab"
   exit /b 58
)
%_ok% "startup tab added to the current window"
exit /b 0


rem Walks wtp.list, gathering one 'new-tab' clause per project still missing,
rem and opens a window at every '---' line and once more at the end of the file.
rem Without a wtp.list there is nothing to walk, and saying so is the whole
rem answer: that file is written by whoever uses wtp, from the shipped example.
:open_project_windows
if not exist "%wtp_list%" (
   %_warning% "No project list yet: '%wtp_list%'"
   %_info% "It names one project folder per line, in tab order, and wtp opens a tab on each"
   if exist "%wtp_example%" (
      %_info% "Copy '%wtp_example%' to '%wtp_list%', then edit it"
   ) else (
      %_warning% "The pattern to copy, '%wtp_example%', is missing too: reinstall senv"
   )
   exit /b 0
)
if not exist "%wtp_tab%" (
   %_fatal% "Missing tab launcher: '%wtp_tab%'" 64
)
rem The per-folder counters of :slot_of belong to this walk alone. One left
rem behind in the environment by an earlier run starts the ranks above 01, and
rem every tab of that folder then looks new and gets opened a second time.
for /f "delims==" %%v in ('set wtp_rank_ 2^>NUL') do set "%%v="
set "wtp_args="
set "wtp_count=0"
set "wtp_open=0"
set "wtp_label="
set "wtp_blocks=0"
set "wtp_failed="
for /f "usebackq eol=# delims=" %%l in ("%wtp_list%") do (
   set "wtp_line=%%l"
   call :add_line
)
call :flush_window
if defined wtp_failed exit /b 61
if "%wtp_blocks%"=="0" (
   %_fatal% "No usable project in '%wtp_list%'" 60
)
exit /b 0


rem Sends the current line of wtp.list either to the window separator or to the
rem tab builder. The first window that fails to open stops the walk, since the
rem for loop this runs in cannot be broken out of.
:add_line
if defined wtp_failed exit /b 0
if "!wtp_line:~0,3!"=="---" (
   call :flush_window
   set "wtp_label=!wtp_line:~3!"
   call :trim wtp_label
   exit /b 0
)
call :add_tab
exit /b 0


rem Opens the tabs still missing from the block gathered so far, then empties
rem the accumulator for the next block of the list. The window carries the name
rem of its block, so a run that only fills a gap hands its tabs to the window
rem already holding their neighbours instead of opening one more.
:flush_window
set /a wtp_total=wtp_count+wtp_open
if "%wtp_total%"=="0" (
   call :reset_window
   exit /b 0
)
set /a wtp_blocks+=1 >NUL
set "wtp_named=window %wtp_blocks%"
set "wtp_window=wtp-%wtp_blocks%"
if defined wtp_label (
   set "wtp_named=window %wtp_blocks% (%wtp_label%)"
   set "wtp_window=wtp-%wtp_label: =-%"
)
if "%wtp_count%"=="0" (
   %_ok% "%wtp_named% already holds its %wtp_open% tab(s)"
   call :reset_window
   exit /b 0
)
rem Windows Terminal lands on the tab it created last; on the run that opens the
rem whole block, the first line of it is the one that should be in front. A run
rem that only fills a gap leaves the focus of the window alone.
if "%wtp_open%"=="0" set "wtp_args=%wtp_args% ; focus-tab -t 0"
if defined wtp_dry (
   %_info% "dry: "%wtp_exe%" -w %wtp_window%%wtp_args%"
   %_info% "dry: %wtp_named%, %wtp_count% tab(s) to open, %wtp_open% already open"
   call :reset_window
   exit /b 0
)
%_task% "Must open %wtp_count% tab(s) of %wtp_named%"
start "" "%wtp_exe%" -w %wtp_window%%wtp_args%
if errorlevel 1 (
   %_error% "Unable to open %wtp_named%"
   set "wtp_failed=1"
   exit /b 61
)
%_ok% "%wtp_named% given %wtp_count% tab(s), %wtp_open% were already open"
call :reset_window
exit /b 0


rem Clears what belongs to one block only.
:reset_window
set "wtp_args="
set "wtp_count=0"
set "wtp_open=0"
set "wtp_label="
exit /b 0


rem Turns wtp_line into one 'new-tab' clause appended to wtp_args, unless the
rem tab it names is already open.
:add_tab
set "wtp_path="
set "wtp_title="
for /f "tokens=1 delims=|" %%p in ("!wtp_line!") do set "wtp_path=%%p"
set "wtp_rest=!wtp_line:*|=!"
if not "!wtp_rest!"=="!wtp_line!" set "wtp_title=!wtp_rest!"
call :trim wtp_path
call :trim wtp_title
if not defined wtp_path exit /b 0

if not exist "!wtp_path!\." (
   %_warning% "Skipping '!wtp_path!': the folder does not exist"
   exit /b 0
)
if not exist "!wtp_path!\senv.bat" (
   %_warning% "'!wtp_path!' holds no senv.bat: its tab only gets the global environment"
)

call :slot_of "!wtp_path!"
call :tab_is_open "!wtp_tab! !wtp_slot!"
if defined wtp_found (
   set /a wtp_open+=1 >NUL
   exit /b 0
)

set /a wtp_count+=1 >NUL
if defined wtp_args set "wtp_args=!wtp_args! ;"
rem A line of wtp.list carrying no title opens its tab with neither --title nor
rem --suppressApplicationTitle, so Windows Terminal keeps honouring the title
rem the application sets and a tool that names its own tab stays in charge.
rem Only a title spelled out in the list is pinned.
if defined wtp_title (
   set "wtp_args=!wtp_args! new-tab --suppressApplicationTitle --title "!wtp_title!" !wtp_p! -d "!wtp_path!" cmd.exe /k !wtp_tab! !wtp_slot!"
) else (
   set "wtp_args=!wtp_args! new-tab !wtp_p! -d "!wtp_path!" cmd.exe /k !wtp_tab! !wtp_slot!"
)
exit /b 0


rem Names the slot the tab of folder %1 fills: the folder itself, plus how many
rem times that folder has already been met in the list. A name tied to the
rem folder rather than to the position of its line keeps the tabs of a project
rem recognisable when another project moves in the list. The rank is padded to
rem two digits so that looking for slot '#01' cannot answer for slot '#10'.
rem
rem The rank counter lives in a variable named after the folder, flattened to
rem the characters a 'set /a' name accepts. A folder that resists flattening
rem makes set /a fail, and falls back to its rank inside the block, which is
rem only less stable when the list is edited.
:slot_of
set "wtp_key=%~1"
set "wtp_key=%wtp_key::=%"
set "wtp_key=%wtp_key:\=_%"
set "wtp_key=%wtp_key:/=_%"
set "wtp_key=%wtp_key: =_%"
set "wtp_key=%wtp_key:-=_%"
set "wtp_key=%wtp_key:.=_%"
set /a "wtp_rank_%wtp_key%+=1" >NUL 2>&1
if errorlevel 1 (
   set /a wtp_rank=wtp_count+wtp_open+1
) else (
   call set "wtp_rank=%%wtp_rank_%wtp_key%%%"
)
if %wtp_rank% lss 10 set "wtp_rank=0%wtp_rank%"
set "wtp_slot=%~1#%wtp_rank%"
exit /b 0


rem Drops the leading and trailing spaces of the variable named %1.
:trim
setlocal enabledelayedexpansion
set "trim_value=!%~1!"
:trim_head
if defined trim_value if "!trim_value:~0,1!"==" " (
   set "trim_value=!trim_value:~1!"
   goto:trim_head
)
:trim_tail
if defined trim_value if "!trim_value:~-1!"==" " (
   set "trim_value=!trim_value:~0,-1!"
   goto:trim_tail
)
endlocal & set "%~1=%trim_value%"
goto:eof


rem The echos macros call this label to name the script logging each line.
:call_echos_stack
if not defined ECHOS_STACK (
    set "CURRENT_SCRIPT=%~nx0" & goto:eof
) else (
    call "%batdir%\echos.bat" :stack %~nx0
)
goto:eof
