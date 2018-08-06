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

	# Write out temp file of modifications with header and footers
	cat <<- EOF > "$1.modtemp"
		##START_MOD##
		#############

		$2

		#############
		###END_MOD###
	EOF

	# Add modifications to head of file
	sed -i "/^#! *\/bin/r $1.modtemp" "$1"
	rm "$1.modtemp"
}

make_exe()
{
	# Make sure dir exists and write file
	mkdir -p `echo "$1" | sed "s|/$( basename $1 )\$||g"`
	echo "$2" > "$1"

	# Make file executable
	chmod +x "$1"
}

restart_delay()
{
	sleep "$1"
	/sbin/shutdown r
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
echo "Checking for config file changes"
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

		exit \$?
	EOF
)"

# Stop swap and backup if disks go away
echo "Adding configs for when SD or USB drive is removed"
add_mod "/etc/udev/script/remove_usb_storage.sh" "$(
	cat <<- EOF
		# Kill the rsync process if the USB drive or SD card is removed
		if [ -f "$PIDFILE" ]; then
			kill \$( cat "$PIDFILE" )
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

		start()
		{
			#
			# Load interface names
			#

			. /sbin/global.sh

			#
			# Default to drop everything
			#

			/bin/iptables -P INPUT DROP
			/bin/iptables -P OUTPUT DROP
			/bin/iptables -P FORWARD DROP

			#
			# Allow everything on loopback
			#

			/bin/iptables -A INPUT  -i "lo" -j ACCEPT
			/bin/iptables -A OUTPUT -o "lo" -j ACCEPT

			#
			# Allow all LAN to LAN & WAN traffic
			#

			/bin/iptables -A FORWARD -i "$lan_if" -o "$lan_if" -j ACCEPT
			/bin/iptables -A FORWARD -i "$lan_if" -o "$wan_if" -j ACCEPT
			/bin/iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

			#
			# Connections to WAN
			#

			# DNS queries
			/bin/iptables -A OUTPUT -o "$wan_if" -p tcp --dport 53   -m state --state NEW,ESTABLISHED -j ACCEPT
			/bin/iptables -A INPUT  -i "$wan_if" -p tcp --sport 53   -m state --state ESTABLISHED     -j ACCEPT
			/bin/iptables -A OUTPUT -o "$wan_if" -p udp --dport 53   -m state --state NEW,ESTABLISHED -j ACCEPT
			/bin/iptables -A INPUT  -i "$wan_if" -p udp --sport 53   -m state --state ESTABLISHED     -j ACCEPT

			# NTP sync
			/bin/iptables -A OUTPUT -o "$wan_if" -p udp --dport 123  -m state --state NEW,ESTABLISHED -j ACCEPT
			/bin/iptables -A INPUT  -i "$wan_if" -p udp --sport 123  -m state --state ESTABLISHED     -j ACCEPT

			#
			# Allow LAN to access router services
			#

			# Pings
			/bin/iptables -A INPUT  -i "$lan_if" -p icmp --icmp-type echo-request -j ACCEPT
			/bin/iptables -A OUTPUT -o "$lan_if" -p icmp --icmp-type echo-reply   -j ACCEPT

			# Telnet
			/bin/iptables -A INPUT  -i "$lan_if" -p tcp --dport 23   -m state --state NEW,ESTABLISHED -j ACCEPT
			/bin/iptables -A OUTPUT -o "$lan_if" -p tcp --sport 23   -m state --state ESTABLISHED     -j ACCEPT

			# HTTP / WebDAV
			/bin/iptables -A INPUT  -i "$lan_if" -p tcp --dport 80   -m state --state NEW,ESTABLISHED -j ACCEPT
			/bin/iptables -A OUTPUT -o "$lan_if" -p tcp --sport 80   -m state --state ESTABLISHED     -j ACCEPT

			# SMB
			/bin/iptables -A INPUT  -i "$lan_if" -p udp --dport 137  -m state --state NEW,ESTABLISHED -j ACCEPT
			/bin/iptables -A OUTPUT -o "$lan_if" -p udp --sport 137  -m state --state ESTABLISHED     -j ACCEPT
			/bin/iptables -A INPUT  -i "$lan_if" -p udp --dport 138  -m state --state NEW,ESTABLISHED -j ACCEPT
			/bin/iptables -A OUTPUT -o "$lan_if" -p udp --sport 138  -m state --state ESTABLISHED     -j ACCEPT
			/bin/iptables -A INPUT  -i "$lan_if" -p tcp --dport 139  -m state --state NEW,ESTABLISHED -j ACCEPT
			/bin/iptables -A OUTPUT -o "$lan_if" -p tcp --sport 139  -m state --state ESTABLISHED     -j ACCEPT
			/bin/iptables -A INPUT  -i "$lan_if" -p tcp --dport 445  -m state --state NEW,ESTABLISHED -j ACCEPT
			/bin/iptables -A OUTPUT -o "$lan_if" -p tcp --sport 445  -m state --state ESTABLISHED     -j ACCEPT

			# DLNA
			/bin/iptables -A INPUT  -i "$lan_if" -p tcp --dport 8200 -m state --state NEW,ESTABLISHED -j ACCEPT
			/bin/iptables -A OUTPUT -o "$lan_if" -p tcp --sport 8200 -m state --state ESTABLISHED     -j ACCEPT

			return 0
		}

		stop()
		{
			# Flush all existing rules
			/bin/iptables -F

			return 0
		}

		block_ipv6()
		{
			/bin/ip -6 -o addr show | while read IPIFID IPDEV IPTYPE IPADDR IPINFO; do
				if [ "lo" = "$IPDEV" ]; then
					continue
				fi

				/bin/ip -6 addr del "$IPADDR" dev "$IPDEV"
			done

			return 0
		}

		case "$1" in
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
			"block_ipv6")
				block_ipv6
				;;
			*)
				echo "Usage: $0 {start|stop|restart|block_ipv6}"
				exit 1
			;;
		esac

		exit $?
	EOF
)"

add_mod "/etc/rc.local" "$(
	cat <<- EOF
		# Turn on firewall, eat errors
		if [ -f "/etc/init.d/firewall" ]; then
			/etc/init.d/firewall start || true

			# Maybe kill IPv6 based on \$ALLOW_IPV6 setting
			if [ "YES" != "$ALLOW_IPV6" ]; then
				/etc/init.d/firewall block_ipv6 || true
			fi
		fi
	EOF
)"

add_mod "/etc/init.d/control.sh" "$(
	cat <<- EOF
		# Restart firewall, eat errors
		if [ -f "/etc/init.d/firewall" ]; then
			/etc/init.d/firewall restart || true

			# Maybe kill IPv6 based on \$ALLOW_IPV6 setting
			if [ "YES" != "$ALLOW_IPV6" ]; then
				/etc/init.d/firewall block_ipv6 || true
			fi
		fi
	EOF
)"

# Commit configuration changes to NVRAM and reboot
echo "Committing changes to disk"
/usr/sbin/etc_tools p

echo "Exiting EnterRouterMode and restarting in 5 seconds"
restart_delay 5 &

exit 0
