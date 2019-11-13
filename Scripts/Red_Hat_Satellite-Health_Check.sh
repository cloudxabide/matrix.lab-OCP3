#!/bin/bash

# Status:   This is the genesis at this point.  Practically just rough notes.
# Author:   jradtke@redhat.com
# Purpose:  Gather some artifcacts to assess health/status of a cluster

command_output() {
echo
echo "#######################"
echo "# ${MSG}"
echo -e "# Command:  ${CMD}"
echo
}

# File System Usage
MSG="File System Check"; 
CMD="df -h | egrep -v '^tmp|^devtmp'"
command_output
df -h | egrep -v '^tmp|^devtmp'

# Memory Usage (current and historical)
MSG="Memory usage - past day"
CMD="sar -r | (head -3 && tail -2)"
command_output
sar -r | (head -3 && tail -2)

CMD="Memory usage - current"
CMD="free -m"
command_output
free -m

# CPU Usage (current and historical)
MSG="CPU Usage"
CMD="sar | (head -5 | grep CPU && tail -1)"
command_output
sar | (head -5 | grep CPU && tail -1)

MSG="CPU Overview - Number of Procs"
CMD="grep ^process /proc/cpuinfo |wc -l"
command_output
echo "`grep ^process /proc/cpuinfo |wc -l` Processors found"

# Network Usage
MSG="Network Usage"
CMD="sar -n DEV | ( head -3 && tail -3 | grep ${INTERFACE}) "
command_output
INTERFACE=`netstat -rn | grep "^0.0.0.0" | awk '{ print $8 }'`
sar -n DEV | ( head -3 && tail -3 | grep ${INTERFACE})

# Disk IO (this might have to be skipped if/when LUKS is used)
MSG="Disk IO"
CMD="sar -d -p | grep Average"
command_output
sar -d -p | grep Average

# Configure password less login for hammer command line tool.
# https://access.redhat.com/solutions/1612123

# subscription-manager repos --enable satellite-tools-6.5-for-rhel-8-x86_64-rpms

# TO BE CONT'D

