#!/bin/sh

##
# Helper Functions
##

add_mod()
{
	# Make sure file and dir exists
	mkdir -p `dirname "$1"`
	touch "$1"

	# Clear any modifications that exist
	sed -i '' '/#START_MOD/,/#END_MOD/d' "$1"

	# Append modifications to file
	echo "##START_MOD##\n\n$2\n\n###END_MOD###" >> "$1"
}

make_exe()
{
	# Make sure file and dir exists
	mkdir -p `dirname "$1"`
	touch "$1"

	# Append modifications to file
	echo "$2" > "$1"

	# Make file executable
	chmod +x "$1"
}

##
# Payload
##

# Maybe skip device setup
CHECKSUM_NEW=$( md5sum "$MNT_USB/EnterRouterMode.sh" )
if [ -f "$CHECKSUM" ]; then
	CHECKSUM_OLD=$( cat "$CHECKSUM" )
else
	CHECKSUM_OLD="N/A"
fi
if [ "$CHECKSUM_OLD" = "$CHECKSUM_NEW" ]; then
	echo "Skipping device setup, no config changes"
	exit 0
fi

# Reset root password to that of 'admin'?
if [ "YES" = "$ROOT_PASS_RESET" ]; then
	echo "Resetting root password to admin password"
	HASH=$( grep -Eo "admin:[^:]+" /etc/passwd | sed 's/admin:\([^:]*\)/\1/' )
	sed -i "s|root:[^:]*|root:$HASH|" /etc/passwd

	HASH=$( grep -Eo "admin:[^:]+" /etc/shadow | sed 's/admin:\([^:]*\)/\1/' )
	sed -i "s|root:[^:]*|root:$HASH|" /etc/shadow
fi

# Allow logins as root?
if [ "YES" = "$ROOT_LOGIN" ]; then
	echo "Enabling root login"
	sed -i "s|:/root:/sbin/nologin|:/root:/bin/sh|" /etc/passwd
else
	echo "Disabling root login"
	sed -i "s|:/root:/bin/sh|:/root:/sbin/nologin|" /etc/passwd
fi

# Turn on telnet access?
if [ "YES" = "$TELNET" ]; then
	echo "Enabling telnet"
	rm -f /etc/checktelnetflag
	touch /etc/telnetflag
else
	echo "Disabling telnet"
	touch /etc/checktelnetflag
	rm -f /etc/telnetflag
fi

# Turn on swap when USB drive is plugged in
SWAP_FILE="$MNT_USB/EnterRouterMode/var/swapfile"
SWAP_LOCK="$MNT_USB/EnterRouterMode/var/swapfile.lock"
SWAP_LOG="$MNT_USB/EnterRouterMode/var/swapfile.log"

make_exe "/etc/init.d/swap" "$(
	cat <<- EOF
		#!/bin/sh

		if [ -d "$MNT_USB/EnterRouterMode" ]; then
			if [ -f "$SWAP_LOCK" ]; then
				echo "[\$(date)] swap.lock exists abort swap creation" >> "$SWAP_LOG"
				exit 0
			else
				touch "$SWAP_LOCK"
				echo "[\$(date)] swap.lock created" >> "$SWAP_LOG"
			fi

			# Check if swap file exists
			if [ -e "$SWAP_FILE" ]; then
				echo "[\$(date)] Found swapfile '$SWAP_FILE'" >> "$SWAP_LOG"
			else
				echo "[\$(date)] Creating 128MB swapfile '$SWAP_FILE'" >> "$SWAP_LOG"
				dd if=/dev/zero of="$SWAP_FILE" bs=1024 count=131072 >> "$SWAP_LOG" 2>&1
				sync >> "$SWAP_LOG" 2>&1
			fi

			# Check if swap file is used
			while read SWPATH SWTYPE SWSIZE SWUSED SWPRI; do
				if [ \$SWPATH = "Filename" ]; then
					continue
				fi

				if [ \$SWPATH = "$SWAP_FILE" ]; then
					echo "[\$(date)] Swap already using '$SWAP_FILE'" >> "$SWAP_LOG"
					rm -f "$SWAP_LOCK"
					exit 0
				fi
			done < /proc/swaps

			echo "[\$(date)] Initializing swapfile '$SWAP_FILE'" >> "$SWAP_LOG"
			/sbin/mkswap "$SWAP_FILE" >> "$SWAP_LOG" 2>&1

			echo "[\$(date)] Turning on swapfile" >> "$SWAP_LOG"
			/sbin/swapon "$SWAP_FILE" >> "$SWAP_LOG" 2>&1
		fi

		rm -f "$SWAP_LOCK"
		exit 0
	EOF
)"

make_exe "/etc/init.d/swap_off" "$(
	cat <<- EOF
		#!/bin/sh

		# Log to USB disk or don't log
		if [ -f "$SWAP_LOG" ]; then
			SWAP_LOG="$SWAP_LOG"
		else
			SWAP_LOG="/dev/null"
		fi

		# Find swapfile and turn it off
		while read SWPATH SWTYPE SWSIZE SWUSED SWPRI; do
			if [ \$SWPATH = "Filename" ]; then
				continue
			fi

			if [ \$SWPATH = "$SWAP_FILE" ]; then
				echo "[\$(date)] Turning off '$SWAP_FILE'" >> "\$SWAP_LOG"
				/sbin/swapoff "$SWAP_FILE" >> "\$SWAP_LOG" 2>&1
				exit 0
			fi
		done < /proc/swaps

		exit 0
	EOF
)"

add_mod "/etc/udev/script/remove_usb_storage.sh" "$(
	cat <<- EOF
		# Kill the rsync process if the USB drive or SD card is removed
		if [ -f $PIDFILE ]; then
			kill $( cat $PIDFILE )
			killall rsync
			rm -f $PIDFILE
		fi

		# Turn off swap on external drive
		/etc/init.d/swap_off
	EOF
)"

# Firewall configs
add_mod "/etc/rc.local" "$(
	cat <<- 'EOF'
		iface="apcli0"

		# Drop all tcp/udp traffic incomming on iface
		/bin/iptables -A INPUT -p tcp -i ${iface} -j DROP
		/bin/iptables -A INPUT -p udp -i ${iface} -j DROP

		# Fetch IPv6 address on iface
		ipv6_addr=`ifconfig ${iface} | grep inet6 | awk {'print $3'}`

		# No IPv6 filter is installed, so remove IPv6 address on iface
		if [ "${ipv6_addr}" != "" ]; then
			/bin/ip -6 addr del "${ipv6_addr}" dev ${iface}
		fi
	EOF
)"

# Write out flag to skip device setup
md5sum "$MNT_USB/EnterRouterMode.sh" > "$CHECKSUM"

# Commit configuration changes to NVRAM
# sync
# /usr/sbin/etc_tools p
