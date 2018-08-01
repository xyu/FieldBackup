#!/bin/sh
set -eu pipefail

# Skip setup if no SD card
if [ ! -d "$MNT_SD" ]; then
	exit 0
fi

# Skip setup if SD card already has a config file
if [ -f "$MNT_SD/FieldBackup.conf" ]; then
	exit 0
fi

# TODO: Skip config if SD card is locked

# Write out a config for new SD card backup
cat <<- EOF > "$MNT_SD/FieldBackup.conf"
	# Name of dir to backup this card to
	SD_NAME="$( cat /proc/sys/kernel/random/uuid )"

	# When set to YES will replicate from USB drive to card
	SD_REPLICA="NO"
EOF
