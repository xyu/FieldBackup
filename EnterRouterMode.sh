#!/bin/sh
set -eu pipefail

##
# Constants - Don't touch
##

MNT_SD="/data/UsbDisk1/Volume1"
MNT_USB="/data/UsbDisk2/Volume1"
PIDFILE="/tmp/EnterRouterMode.pid"

##
# Helper functions
##

run()
{
	# Make sure the file exists
	if [ ! -f "$MNT_USB/EnterRouterMode/$1" ]; then
		echo "'$1' not found"
		exit 1
	fi

	echo "Executing '$MNT_USB/EnterRouterMode/$1'"
	. "$MNT_USB/EnterRouterMode/$1"
}

cleanup()
{
	# Capture last exit status
	local STATUS="$?"

	# Remove pidfile if it's ours
	if [ $( cat "$PIDFILE" ) -eq "$$" ]; then
		rm -f "$PIDFILE"
	fi

	if [ "$STATUS" -eq "0" ]; then
		echo "EnterRouterMode.sh [$$] completed @ `date`"
	else
		echo "EnterRouterMode.sh [$$] failed @ `date`"
	fi
}

##
# Payload
##

# Create runtime dirs
mkdir -p "$MNT_USB/EnterRouterMode/var"

# Set all output to logfile
exec 1>> "$MNT_USB/EnterRouterMode/var/EnterRouterMode.log" 2>&1

# Trap errors
trap cleanup 0 1 2 3 9 15

# Print header to log file
echo "EnterRouterMode.sh [$$] started @ `date`"

# Basic bootstrap checks
[ -d "$MNT_USB/EnterRouterMode" ]
[ -f "$MNT_USB/EnterRouterMode.sh" ]

# Wait if another process is already running
while [ -f "$PIDFILE" ]; do
	PID=$( cat "$PIDFILE" )
	if ps -o pid | grep "$PID" > /dev/null; then
		# pidfile reference running process let's wait
		sleep 30
	else
		# pidfile exists but process is not running so remove file
		rm -f "$PIDFILE"
	fi
done

# Write out pidfile only if one does not exist (eek race conditions!)
[ ! -f "$PIDFILE" ] && echo "$$" > "$PIDFILE"

# Load configs
run conf

# TODO: Start flashing lights

# Check battery power, don't try to write data if power's low
if [ `cat /proc/vs_battery_quantity` -lt "20" ]; then
	echo "Battery at less then 20% full, bailing"
	exit 1
fi

# Setup the RP-WD03 device and SD card if needed
run bin/device-setup.sh
run bin/sdcard-setup.sh

# Do rsync, we need more memory so turn on swap for just this action
run bin/device-swapon.sh
# TODO: SD Card start sync
run bin/device-swapoff.sh

# TODO: Stop flashing lights
