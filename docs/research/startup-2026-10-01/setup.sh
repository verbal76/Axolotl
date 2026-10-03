#!/bin/bash
S=/tmp/claude-0/-home-user-Axolotl/662cc549-a6ca-5666-89fb-e26c9400328b/scratchpad/startup
for r in 041 044 030; do
  mkdir -p $S/src$r && tar -xf $S/r$r.tar -C $S/src$r
done
for r in 041 044 030; do
  TMO=600 $S/run.sh $S/src$r $S/import$r.log --headless --path . --import
done
