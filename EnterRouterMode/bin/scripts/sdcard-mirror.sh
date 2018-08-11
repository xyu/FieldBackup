#!/bin/sh

##
# Helper Functions
##

eject_sd_card()
{
	local MOUNTPOINT=""

	while read -r _ MOUNTPOINT _ ; do
		if [ "$MOUNTPOINT" != "$MNT_SD" ]; then
			continue
		fi

		umount "$MOUNTPOINT" || umount2 "$MOUNTPOINT" || true
		return 0
	done < /proc/mounts
}

# Load configs for mirroring
. "$CONFIGFILE"

if [ "YES" = "$SD_REPLICA" ]; then
	if sd_is_readonly; then
		echo "Can not mirror data from USB drive onto locked SD card"
		return 1
	fi

	echo "Mirroring '$SD_NAME' on USB drive to SD card"

	SYNC_LOG="$MNT_USB/EnterRouterMode/log/SDCard.$SD_NAME.Replica.log"
	SYNC_SOURCE="$MNT_USB/SDMirrors/$SD_NAME"
	SYNC_TARGET="$MNT_SD"

	mkdir -p "$SYNC_SOURCE"
else
	echo "Mirroring SD card '$SD_NAME' to USB drive"

	SYNC_LOG="$MNT_USB/EnterRouterMode/log/SDCard.$SD_NAME.Primary.log"
	SYNC_SOURCE="$MNT_SD"
	SYNC_TARGET="$MNT_USB/SDMirrors/$SD_NAME"

	mkdir -p "$SYNC_TARGET"
fi

"$MNT_USB/EnterRouterMode/bin/rsync" \
	--recursive \
	--times \
	--prune-empty-dirs \
	--ignore-existing \
	--stats \
	--human-readable \
	--log-file="$SYNC_LOG" \
	--exclude="$( basename "$CONFIGFILE" )" \
	"$SYNC_SOURCE/" \
	"$SYNC_TARGET"

sync

echo "Ejecting SD card"
eject_sd_card

return 0
