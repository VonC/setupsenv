#!/bin/bash
DIR="$( cd "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )"
#echo "Hello from Bash from '${DIR}'!"
echo "done"
setis=$(cygpath -u "${PRGS}/sysinternalSuites/current")
echo "setis='${setis}'"
prg="cmd"
if [ ! "${1}" == "" ]; then
  prg="${1}"
fi
output=$("${setis}/pslist.exe" -d "${prg}")

# Process the output line by line
while read -r line; do
  if [ ! "${line#"${prg}" }" = "${line}" ]; then
    pid="${line/${prg} /}"
    pid="${pid%:*}"
    echo "Process pid '${pid}'"
  fi
  if [ ! "${line#*Wait:Suspended}" = "${line}" ]; then
    echo "  Must resume Process ID '${pid}'"
    powershell -ExecutionPolicy Bypass -File "${DIR}/resumep.ps1" "${pid}"
    # powershell -ExecutionPolicy Bypass -c "Get-CimInstance Win32_Process -Filter \"processid=$1\" | Select-Object -ExpandProperty CommandLine"
    if "${setis}/pssuspend.exe" -r "${pid}"; then
      echo "  OK: Resumed Process ID '${pid}'"
    else
      echo "  KO: FAILED to resume Process ID '${pid}'"
    fi
  fi
done <<< "${output}"