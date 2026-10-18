#!/bin/zsh
# Final kitbash renders, one at a time, pausing on thermal warnings or low battery.
B=/Applications/Blender.app/Contents/MacOS/Blender
OUT=${0:A:h}/kit-renders
mkdir -p $OUT
for scene in monkeyball dessert moon hollow hexboard planetoid outpost garden; do
  [[ -f $OUT/$scene.png ]] && continue
  while true; do
    battery=$(pmset -g batt | grep -o '[0-9]*%' | tr -d '%')
    charging=$(pmset -g batt | grep -c "AC Power")
    warning=$(pmset -g therm | grep -ci "warning level.*[1-9]")
    if [[ $warning -gt 0 ]]; then echo "$(date +%T) thermal warning, cooling down"; sleep 60; continue; fi
    if [[ $charging -eq 0 && $battery -lt 30 ]]; then echo "$(date +%T) battery $battery%, waiting"; sleep 120; continue; fi
    break
  done
  start=$(date +%s)
  $B -b -P ${0:A:h}/kitbash.py -- --scene $scene --width 1600 --height 1000 --samples 128 --out $OUT/$scene.png > $OUT/$scene.log 2>&1
  echo "$(date +%T) $scene $(( $(date +%s) - start ))s battery $(pmset -g batt | grep -o '[0-9]*%') $(grep -c Error $OUT/$scene.log) errors"
done
echo done
