@echo off
rem https://superuser.com/questions/194659/how-to-disable-the-output-of-7-zip
for /F "delims=," %%i in ('echo %1') do "%sz%" x -aos -pdefault -sccUTF-8 %%i -o"%%~ni" -bso0 -bsp1
@echo off
rem for /F "delims=," %%i in ('echo %1') do set "res=%%i"
rem echo "res='%res%'"