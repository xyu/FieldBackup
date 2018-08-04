#!/bin/sh

# Skip setup if no SD card
if [ ! -d "$MNT_SD" ]; then
	return 0
fi

# Skip setup if SD card already has a config file
if [ -f "$CONFIGFILE" ]; then
	return 0
fi

# Skip setup if SD card is locked
if sd_is_readonly; then
	return 0
fi

# Write out a config for new SD card backup
cat <<- EOF > "$CONFIGFILE"
	##
	# Field Backup with RAVPower FileHub Plus
	# https://github.com/xyu/FieldBackup
	##

	# Name of dir to backup this card to
	SD_NAME="$( cat /proc/sys/kernel/random/uuid )"

	# When set to YES will replicate from USB drive to card
	SD_REPLICA="NO"
EOF
