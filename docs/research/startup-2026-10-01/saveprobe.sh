#!/bin/bash
S=/tmp/claude-0/-home-user-Axolotl/662cc549-a6ca-5666-89fb-e26c9400328b/scratchpad/startup
mkdir -p $S/pristine && tar -xf $S/rcur.tar -C $S/pristine scripts
cd $S
diff -ru pristine/scripts probe/scripts > $S/TEMP_PROBES.patch
echo "patch lines: $(wc -l < $S/TEMP_PROBES.patch)"
rm -rf $S/probe $S/pristine $S/home.* $S/xh $S/xup_home
ls $S
