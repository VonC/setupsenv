#!/bin/bash

# Function to handle CTRL-C
function handle_ctrl_c() {
    echo "CTRL-C detected. Exiting immediately..."
    exit 1
}

# Trap CTRL-C (SIGINT)
trap handle_ctrl_c SIGINT

DIR="$( cd "$( dirname "$(readlink -f "${BASH_SOURCE[0]}")" )" && pwd )"
#echo "Hello from Bash from '${DIR}'!"
echo "done"
setis=$(cygpath -u "${PRGS}/sysinternalSuites/current")
echo "setis='${setis}'"
prg="cmd"
if [ ! "${1}" == "" ]; then
  prg="${1}"
fi
echo "pslist for prg '${prg}'"
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

#!/bin/bash

if [ ! "${2}" == "" ]; then
  total=$2
  for ((i=1; i<=total; i++)); do
    powershell -ExecutionPolicy Bypass -File "${DIR}/progress_bar.ps1" -total "${total}" -current $i
    sleep 0.1  # Optional: Add a sleep to simulate progress
  done
fi