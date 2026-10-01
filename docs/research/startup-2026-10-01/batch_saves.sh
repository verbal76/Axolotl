#!/bin/bash
# with an existing (dev-000041-written) save: first launch (migration where the version does it) then second launch, same user dir
S=/tmp/claude-0/-home-user-Axolotl/662cc549-a6ca-5666-89fb-e26c9400328b/scratchpad/startup
CUR=/home/user/Axolotl/.claude/worktrees/agent-a43f417d7c150e9a9
N=${N:-3}
OUT=$S/${OUT:-hs}
mkdir -p $OUT
for i in $(seq 1 $N); do
  for v in cur 041 044; do
    if [ $v = cur ]; then P=$CUR; else P=$S/src$v; fi
    HH=$(mktemp -d $S/home.XXXX)
    H=$HH SAVES=$S/saves041 TMO=120 $S/run.sh $P $OUT/${v}first_$i.log ${GARGS:---headless} --path . -- --startup-probe > /dev/null
    H=$HH TMO=120 $S/run.sh $P $OUT/${v}second_$i.log ${GARGS:---headless} --path . -- --startup-probe > /dev/null
    cp $HH/d/godot/app_userdata/Mote/gill_progress.json $OUT/${v}_gill_after_$i.json 2>/dev/null
  done
done
echo done
