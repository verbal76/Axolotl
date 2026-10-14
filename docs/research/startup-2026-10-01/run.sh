#!/bin/bash
# usage: [H=existing_home] [SAVES=dir] [XVFB=1] run.sh <project_dir> <log> [godot args...]
P="$1"; shift
LOG="$1"; shift
if [ -z "$H" ]; then
  H=$(mktemp -d /tmp/claude-0/-home-user-Axolotl/662cc549-a6ca-5666-89fb-e26c9400328b/scratchpad/startup/home.XXXX)
fi
if [ -n "$SAVES" ]; then
  mkdir -p $H/d/godot/app_userdata/Mote
  cp $SAVES/* $H/d/godot/app_userdata/Mote/
fi
export HOME=$H XDG_DATA_HOME=$H/d XDG_CONFIG_HOME=$H/c
cd "$P"
if [ -n "$XVFB" ]; then
  timeout ${TMO:-300} xvfb-run -a -s "-screen 0 1280x720x24" /home/user/tools/godot "$@" > "$LOG" 2>&1
else
  timeout ${TMO:-300} /home/user/tools/godot "$@" > "$LOG" 2>&1
fi
echo "exit $? home=$H"
