#!/bin/sh

# Load configs for mirroring
. "$CONFIGFILE"

if [ "YES" = "$SD_REPLICA" ]; then
	if sd_is_readonly; then
		echo "Can not mirror data from USB drive onto locked SD card"
		return 1
	fi

	echo "Mirroring '$SD_NAME' on USB drive to SD card"

	SYNC_LOG="$MNT_USB/EnterRouterMode/log/$SD_NAME.SDCardReplica.log"
	SYNC_SOURCE="$MNT_USB/SDMirrors/$SD_NAME"
	SYNC_TARGET="$MNT_SD"

	mkdir -p "$SYNC_SOURCE"
else
	echo "Mirroring SD card '$SD_NAME' to USB drive"

	SYNC_LOG="$MNT_USB/EnterRouterMode/log/$SD_NAME.SDCard.log"
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
	--exclude="$( basename $CONFIGFILE )" \
	"$SYNC_SOURCE/" \
	"$SYNC_TARGET"

sync

echo "Ejecting SD card"
while read DEVICE MOUNTPOINT FSTYPE RWROINFO; do
  if [ "$MOUNTPOINT" != "$MNT_SD" ]; then
    continue
  fi

  umount "$MOUNTPOINT" || umount2 "$MOUNTPOINT" || true
done < /proc/mounts

return 0
