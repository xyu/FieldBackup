#!/bin/sh

##
# Field Backup with RAVPower FileHub Plus
# https://github.com/xyu/FieldBackup
##

# Log all output to logfile on USB disk or just echo to stdout
if [ -d "$MNT_USB/EnterRouterMode" ]; then
	touch "$SWAP_LOG"
	exec 1>> "$SWAP_LOG" 2>&1
fi

logmsg()
{
	echo "[$( date -u '+%F %T' )]" "$@"
}

start()
{
	local SWPATH=""

	logmsg "Trying to start swapping to '$SWAP_FILE'"

	# Check if swap file is already used
	while read -r SWPATH _ ; do
		if [ "$SWAP_FILE" != "$SWPATH" ]; then
			continue
		fi

		logmsg "Already swapping to USB drive swapfile"
		return 0
	done < /proc/swaps

	# Can't start if no attached drive
	if [ ! -d "$MNT_USB/EnterRouterMode" ]; then
		logmsg "Aborting; no drive attached"
		return 1
	fi

	# Check lock to ensure concurrency of 1
	if [ -f "$SWAP_LOCK" ]; then
		logmsg "Aborting; swap.lock exists"
		return 1
	fi

	touch "$SWAP_LOCK"
	logmsg "swap.lock created"

	# Check if swap file exists
	if [ -e "$SWAP_FILE" ]; then
		logmsg "Found swapfile"
	else
		logmsg "Creating swapfile (128MB)"
		dd if="/dev/zero" of="$SWAP_FILE" bs="1M" count="128"
		sync
	fi

	logmsg "Initializing swapfile"
	/sbin/mkswap "$SWAP_FILE"

	logmsg "Turning on swapfile"
	/sbin/swapon "$SWAP_FILE"

	rm -f "$SWAP_LOCK"
	logmsg "swap.lock removed"

	return 0
}

stop()
{
	local SWPATH=""

	logmsg "Trying to stop swapping to '$SWAP_FILE'"

	# Find swapfile and turn it off
	while read -r SWPATH _ ; do
		if [ "$SWAP_FILE" != "$SWPATH" ]; then
			continue
		fi

		logmsg "Turning off swapping to USB drive swapfile"
		/sbin/swapoff "$SWAP_FILE"
		return 0
	done < /proc/swaps

	logmsg "Was not swapping to USB drive swapfile"
	return 0
}

case "$1" in
	"start")
		start
		;;
	"stop")
		stop
		;;
	*)
		echo "Usage: $0 {start|stop}"
		exit 1
	;;
esac

exit $?
