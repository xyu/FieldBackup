#!/bin/sh
set -eu

##
# Field Backup with RAVPower FileHub Plus
# https://github.com/xyu/FieldBackup
#
# A set of scripts that will automatically backup SD cards inserted into the
# RAVPower FileHub Plus (RP-WD03) onto the attached USB drive.
#
# Do not touch this file configure device setup options with:
# ./EnterRouterMode/conf
##

##
# Constants
##

MNT_SD="/data/UsbDisk1/Volume1"
MNT_USB="/data/UsbDisk2/Volume1"
PIDFILE="/tmp/EnterRouterMode.pid"
CONFIGFILE="$MNT_SD/FieldBackup.conf"

##
# Vars / Flags
##

WINKING="FALSE"
RESTART="FALSE"

##
# Helper functions
##

led_wink()
{
	case "$1" in
		"ON")
			if [ "FALSE" = "$WINKING" ]; then
				WINKING="TRUE"
				/usr/sbin/pioctl status 2 || true
			fi
			;;
		"OFF")
			if [ "TRUE" = "$WINKING" ]; then
				WINKING="FALSE"
				/usr/sbin/pioctl status 3 || true
			fi
			;;
	esac
}

sd_is_readonly()
{
	while read DEVICE MOUNTPOINT FSTYPE RWROINFO; do
		if [ "$MOUNTPOINT" != "$MNT_SD" ]; then
			continue
		fi

		if [ "ro" = "${RWROINFO:0:2}" ]; then
			return 0
		else
			return 1
		fi
	done < /proc/mounts

	# Pretend we're readonly if mount does not exist
	return 0
}

run()
{
	# Make sure the file exists
	if [ ! -f "$MNT_USB/EnterRouterMode/$1" ]; then
		echo "'$1' not found"
		return 1
	fi

	echo "Executing '$MNT_USB/EnterRouterMode/$1'"
	. "$MNT_USB/EnterRouterMode/$1"
}

get_concurrency_lock()
{
	local COUNT="0"

	while [ -f "$PIDFILE" ]; do
		if ps -o pid,args | grep -E "^ *$( cat $PIDFILE ) .+EnterRouterMode.sh" > /dev/null; then
			# pidfile reference running process let's wait
			if [ "$COUNT" -lt "30" ]; then
				# For the first minute check every 2 seconds
				sleep 2
			elif [ "$COUNT" -lt "40" ]; then
				# For the next 5 minutes check every 30 seconds
				sleep 30
			else
				# Still locked so kill current process
				echo "Could not aquire lock after 6 minutes"
				return 1
			fi
			COUNT=`expr $COUNT + 1`
		else
			# pidfile exists but process is not running EnterRouterMode so remove file
			rm -f "$PIDFILE"
		fi
	done

	# Write out pidfile only if one does not exist (eek race conditions!)
	[ ! -f "$PIDFILE" ] && echo "$$" > "$PIDFILE"
}

cleanup()
{
	# Capture last exit status
	local STATUS="$?"
	local COUNT="0"

	# Make sure we end execution if we get another signal again
	trap "suicide" 0 1 2 3 9 15

	if [ "$STATUS" -eq "0" ]; then
		echo "EnterRouterMode.sh [$$][`date -u '+%F %T'`] completed"
	else
		echo "EnterRouterMode.sh [$$][`date -u '+%F %T'`] failed"
	fi

	# Persist to disk and wait
	sync
	sleep 2

	# Stop flashing lights
	led_wink "OFF"

	# Trigger restart and wait to block other concurrent calls from starting
	if [ "TRUE" = "$RESTART" ]; then
		/sbin/shutdown r &

		COUNT="0"
		while [ "$COUNT" -lt "60" ]; do
			sleep 1
			COUNT=`expr $COUNT + 1`
		done
	fi

	# Remove pidfile if it's ours
	if [ -f "$PIDFILE" ]; then
		if [ $( cat "$PIDFILE" ) -eq "$$" ]; then
			rm -f "$PIDFILE"
		fi
	fi
}

suicide()
{
  exit $?
}

##
# Payload
##

# Create runtime dirs
mkdir -p "$MNT_USB/EnterRouterMode/var"
mkdir -p "$MNT_USB/EnterRouterMode/log"

# Set all output to logfile
exec 1>> "$MNT_USB/EnterRouterMode/log/EnterRouterMode.log" 2>&1

# Trap errors
trap "cleanup" 0 1 2 3 9 15

# Print header to log file
echo "EnterRouterMode.sh [$$][`date -u '+%F %T'`] started"

# Basic bootstrap checks
[ -d "$MNT_USB/EnterRouterMode" ]
[ -f "$MNT_USB/EnterRouterMode.sh" ]

# Start flashing lights
led_wink "ON"

# Wait if another process is already running
get_concurrency_lock

# Check battery power, don't try to write data if power's low
if [ `cat /proc/vs_battery_quantity` -lt "20" ]; then
	echo "Battery at less then 20% full, bailing"
	exit 1
fi

# Load configs
run conf

# Setup the RP-WD03 device and SD card if needed
run bin/scripts/device-setup.sh
run bin/scripts/sdcard-setup.sh

# Do rsync, we need more memory so turn on swap for just this action
if [ -f "$CONFIGFILE" ]; then
	run bin/scripts/device-swapon.sh
	run bin/scripts/sdcard-mirror.sh
	run bin/scripts/device-swapoff.sh
fi
