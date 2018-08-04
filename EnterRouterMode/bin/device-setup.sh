#!/bin/sh

##
# Helper Functions
##

add_mod()
{
	# Make sure file and dir exists
	mkdir -p `echo "$1" | sed "s|/$( basename $1 )\$||g"`
	touch "$1"

	# Clear any modifications that exist
	sed -i '/##START_MOD##/,/###END_MOD###/d' "$1"

	# Add modifications to head of file
	cat <<- EOF | sed -i -e '/^#!\s*\/bin/r /dev/stdin' "$1"
		##START_MOD##
		#############

		$2

		#############
		###END_MOD###
	EOF
}

make_exe()
{
	# Make sure file and dir exists
	mkdir -p `echo "$1" | sed "s|/$( basename $1 )\$||g"`
	touch "$1"

	# Append modifications to file
	echo "$2" > "$1"

	# Make file executable
	chmod +x "$1"
}

##
# Setup device on config change
##

# Write out a fake checksum if this is first time setup
CHECKSUM="/etc/EnterRouterMode.checksum"
if [ ! -f "$CHECKSUM" ]; then
	echo "00000000000000000000000000000000  $MNT_USB/EnterRouterMode.sh" > "$CHECKSUM"
fi

# Skip device setup if it's setup with current config files
if md5sum -c "$CHECKSUM"; then
	return 0
fi

# Write out checksums to skip device setup next time
md5sum \
	"$MNT_USB/EnterRouterMode.sh" \
	"$MNT_USB/EnterRouterMode/conf" \
	"$MNT_USB/EnterRouterMode/bin/device-setup.sh" \
	> "$CHECKSUM"

##
# Payload
##

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
echo "Writing out configs for using a swapfile on USB drive"
SWAP_FILE="$MNT_USB/EnterRouterMode/var/swapfile"
SWAP_LOCK="$MNT_USB/EnterRouterMode/var/swapfile.lock"
SWAP_LOG="$MNT_USB/EnterRouterMode/log/swapfile.log"

touch "$SWAP_LOG"

make_exe "/etc/init.d/swap_to_usb_storage" "$(
	cat <<- EOF
		#!/bin/sh

		start()
		{
			# Can't start if no attached drive
			if [ ! -d "$MNT_USB/EnterRouterMode" ]; then
				return 1
			fi

			if [ -f "$SWAP_LOCK" ]; then
				echo "[\$(date)] swap.lock exists abort swap creation" >> "$SWAP_LOG"
				return 1
			else
				touch "$SWAP_LOCK"
				echo "[\$(date)] swap.lock created" >> "$SWAP_LOG"
			fi

			# Check if swap file exists
			if [ -e "$SWAP_FILE" ]; then
				echo "[\$(date)] Found swapfile '$SWAP_FILE'" >> "$SWAP_LOG"
			else
				echo "[\$(date)] Creating 128MB swapfile '$SWAP_FILE'" >> "$SWAP_LOG"
				dd if=/dev/zero of="$SWAP_FILE" bs=1M count=128 >> "$SWAP_LOG" 2>&1
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
					return 0
				fi
			done < /proc/swaps

			echo "[\$(date)] Initializing swapfile '$SWAP_FILE'" >> "$SWAP_LOG"
			/sbin/mkswap "$SWAP_FILE" >> "$SWAP_LOG" 2>&1

			echo "[\$(date)] Turning on swapfile" >> "$SWAP_LOG"
			/sbin/swapon "$SWAP_FILE" >> "$SWAP_LOG" 2>&1

			rm -f "$SWAP_LOCK"
			return 0
		}

		stop()
		{
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
					return 0
				fi
			done < /proc/swaps

			return 0
		}

		case "\$1" in
			"start")
				start
				;;
			"stop")
				stop
				;;
			*)
				echo "Usage: \$0 {start|stop}"
				exit 1
			;;
		esac

		exit $?
	EOF
)"

# Stop swap and backup if disks go away
echo "Adding configs for when SD or USB drive is removed"
add_mod "/etc/udev/script/remove_usb_storage.sh" "$(
	cat <<- EOF
		# Kill the rsync process if the USB drive or SD card is removed
		if [ -f "$PIDFILE" ]; then
			kill $( cat "$PIDFILE" )
			killall rsync
			rm -f "$PIDFILE"
		fi

		# Turn off swap on external drive, eat errors
		if [ -f "/etc/init.d/swap_to_usb_storage" ]; then
			/etc/init.d/swap_to_usb_storage stop || true
		fi
	EOF
)"

# Firewall configs
echo "Adding firewall configs to startup script"

make_exe "/etc/init.d/firewall" "$(
	cat <<- 'EOF'
		#!/bin/sh
		iface="apcli0"



		start()
		{
			# Drop all tcp/udp traffic incomming on iface
			/bin/iptables -A INPUT -p tcp -i ${iface} -j DROP
			/bin/iptables -A INPUT -p udp -i ${iface} -j DROP

			# Fetch IPv6 address on iface
			ipv6_addr=`ifconfig ${iface} | grep inet6 | awk {'print $3'}`

			# No IPv6 filter is installed, so remove IPv6 address on iface
			if [ "${ipv6_addr}" != "" ]; then
				/bin/ip -6 addr del "${ipv6_addr}" dev "${iface}"
			fi

			return 0
		}

		stop()
		{
			# Flush all existing rules
			/bin/iptables -F

			return 0
		}

		case "\$1" in
			"start")
				start
				;;
			"stop")
				stop
				;;
			"restart")
				stop
				start
				;;
			*)
				echo "Usage: \$0 {start|stop|restart}"
				exit 1
			;;
		esac

		exit $?
	EOF
)"

add_mod "/etc/rc.local" "$(
	cat <<- 'EOF'
		/etc/init.d/firewall start
	EOF
)"

add_mod "/etc/init.d/control.sh" "$(
	cat <<- 'EOF'
		/etc/init.d/firewall restart
	EOF
)"

# Commit configuration changes to NVRAM and reboot
echo "Committing changes to disk and restarting..."
/usr/sbin/etc_tools p
/sbin/shutdown r &
exit 0
