#!/bin/bash
# alternate versions, N rounds, headless startup probe, fresh user dir each run
S=/tmp/claude-0/-home-user-Axolotl/662cc549-a6ca-5666-89fb-e26c9400328b/scratchpad/startup
CUR=/home/user/Axolotl/.claude/worktrees/agent-a43f417d7c150e9a9
N=${N:-5}
mkdir -p $S/hl
for i in $(seq 1 $N); do
  for v in cur 041 044 030; do
    if [ $v = cur ]; then P=$CUR; else P=$S/src$v; fi
    TMO=120 $S/run.sh $P $S/hl/${v}_$i.log --headless --path . -- --startup-probe > /dev/null
  done
done
echo done
