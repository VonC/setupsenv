set "senv_noconfirm=1"
echo "0 senv_noconfirm='%senv_noconfirm%' '!senv_noconfirm!'"
call setup.bat %*
set senv_noconfirm=