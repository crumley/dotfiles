#!/bin/bash

# To refresh token `rclone config reconnect drive:`

mypidfile=/tmp/rclone-cron.sh.pid

# Could add check for existence of mypidfile here if interlock is
# needed in the shell script itself.

# Ensure PID file is removed on program exit.
trap "rm -f -- '$mypidfile'" EXIT

# Create a file with current PID to indicate that process is running.
echo $$ > "$mypidfile"

/usr/local/bin/rclone sync ~/Documents/brain2 drive:brain2
