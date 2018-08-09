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

		# Log all output to logfile on USB disk or just echo to stdout
		if [ -f "$SWAP_LOG" ]; then
			exec 1>> "$SWAP_LOG" 2>&1
		fi

		logmsg()
		{
			echo "[\$( date -u '+%F %T' )] \$@"
		}

		start()
		{
			logmsg "Trying to start swapping to '$SWAP_FILE'"

			# Check if swap file is already used
			while read SWPATH SWTYPE SWSIZE SWUSED SWPRI; do
				if [ "$SWAP_FILE" != "\$SWPATH" ]; then
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
				dd if=/dev/zero of="$SWAP_FILE" bs=1M count=128
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
			logmsg "Trying to stop swapping to '$SWAP_FILE'"

			# Find swapfile and turn it off
			while read SWPATH SWTYPE SWSIZE SWUSED SWPRI; do
				if [ "$SWAP_FILE" != "\$SWPATH" ]; then
					continue
				fi

				logmsg "Turning off swapping to USB drive swapfile"
				/sbin/swapoff "$SWAP_FILE"
				return 0
			done < /proc/swaps

			logmsg "Was not swapping to USB drive swapfile"
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
			# Check that we are starting with empty chains
			#

			if [ $( /bin/iptables -S | wc -l ) -gt 3 ]; then
				echo "Chains for 'filter' table not empty. Use $0 restart to flush and add chains"
				return 1
			fi

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

			/bin/iptables -A INPUT   -i "lo" -j ACCEPT
			/bin/iptables -A OUTPUT  -o "lo" -j ACCEPT

			#
			# Allow all LAN to LAN & WAN traffic
			#

			/bin/iptables -A FORWARD -i "$lan_if" -j ACCEPT

			#
			# Allow previously established connections
			#

			/bin/iptables -A INPUT   -m state --state RELATED,ESTABLISHED -j ACCEPT
			/bin/iptables -A OUTPUT  -m state --state RELATED,ESTABLISHED -j ACCEPT
			/bin/iptables -A FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT

			#
			# Connections to WAN
			#

			# DHCP (client)
			/bin/iptables -A OUTPUT -o "$wan_if" -p udp --sport 68    -j ACCEPT
			/bin/iptables -A INPUT  -i "$wan_if" -p udp --dport 68    -j ACCEPT

			# DNS queries
			/bin/iptables -A OUTPUT -o "$wan_if" -p tcp --dport 53    -j ACCEPT
			/bin/iptables -A OUTPUT -o "$wan_if" -p udp --dport 53    -j ACCEPT

			# NTP sync
			/bin/iptables -A OUTPUT -o "$wan_if" -p udp --dport 123   -j ACCEPT

			#
			# Allow LAN to access router services
			#

			# Pings
			/bin/iptables -A INPUT  -i "$lan_if" -p icmp --icmp-type echo-request -j ACCEPT
			/bin/iptables -A OUTPUT -o "$lan_if" -p icmp --icmp-type echo-reply   -j ACCEPT

			# DHCP (server)
			/bin/iptables -A INPUT  -i "$lan_if" -p udp --dport 67   -j ACCEPT
			/bin/iptables -A OUTPUT -o "$lan_if" -p udp --sport 67   -j ACCEPT

			# Telnet
			/bin/iptables -A INPUT  -i "$lan_if" -p tcp --dport 23   -j ACCEPT

			# HTTP / WebDAV
			/bin/iptables -A INPUT  -i "$lan_if" -p tcp --dport 80   -j ACCEPT

			# SMB
			/bin/iptables -A INPUT  -i "$lan_if" -p udp --dport 137  -j ACCEPT
			/bin/iptables -A INPUT  -i "$lan_if" -p udp --dport 138  -j ACCEPT
			/bin/iptables -A INPUT  -i "$lan_if" -p tcp --dport 139  -j ACCEPT
			/bin/iptables -A INPUT  -i "$lan_if" -p tcp --dport 445  -j ACCEPT

			# DLNA
			/bin/iptables -A INPUT  -i "$lan_if" -p tcp --dport 8200 -j ACCEPT

			return 0
		}

		stop()
		{
			# Accept all traffic by default
			/bin/iptables -P INPUT ACCEPT
			/bin/iptables -P OUTPUT ACCEPT
			/bin/iptables -P FORWARD ACCEPT

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

# Flag as restart needed and exit EnterRouterMode
RESTART="TRUE"
exit 0
