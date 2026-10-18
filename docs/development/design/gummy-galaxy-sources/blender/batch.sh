#!/bin/zsh
# Renders one shot at a time, pausing on low battery or thermal warnings.
B=/Applications/Blender.app/Contents/MacOS/Blender
OUT=${0:A:h}/renders
mkdir -p $OUT
shots=(
  "orrery gummy full tide 1080 1080 96"
  "companion gummy pair tide 1080 1080 96"
  "orrery gummy pair grape 1080 1080 96"
  "companion-happy plush full studio 1080 1080 96"
  "orrery clay full studio 1080 1080 96"
  "bear gummy full grape 1080 1080 96"
  "gumdrop gummy full tide 1080 1080 96"
  "orrery plush full peach 1080 1080 96"
  "pop hardcandy full peach 1080 1080 96"
  "companion clay full peach 1080 1080 96"
  "belt gummy full grape 1080 1080 96"
  "orrery plastic full tide 1080 1080 96"
  "diorama gummy full tide 1600 1000 128"
  "diorama clay full studio 1600 1000 112"
)
for shot in $shots; do
  parts=(${=shot})
  name="${parts[1]}-${parts[2]}-${parts[3]}-${parts[4]}"
  [[ -f $OUT/$name.png ]] && continue
  while true; do
    battery=$(pmset -g batt | grep -o '[0-9]*%' | tr -d '%')
    charging=$(pmset -g batt | grep -c "AC Power")
    warning=$(pmset -g therm | grep -ci "warning level.*[1-9]\|CPU_Speed_Limit.*[0-8][0-9]\b")
    if [[ $warning -gt 0 ]]; then echo "$(date +%T) thermal warning, cooling down"; sleep 60; continue; fi
    if [[ $charging -eq 0 && $battery -lt 30 ]]; then echo "$(date +%T) battery at $battery%, waiting for power"; sleep 60; continue; fi
    break
  done
  start=$(date +%s)
  $B -b -P ${0:A:h}/gummy_scene.py -- --shot ${parts[1]} --style ${parts[2]} --palette ${parts[3]} --bg ${parts[4]} --width ${parts[5]} --height ${parts[6]} --samples ${parts[7]} --out $OUT/$name.png > $OUT/$name.log 2>&1
  echo "$(date +%T) $name $(( $(date +%s) - start ))s battery ${battery}% $(grep -c Traceback $OUT/$name.log) errors"
  sleep 8
done
echo done
