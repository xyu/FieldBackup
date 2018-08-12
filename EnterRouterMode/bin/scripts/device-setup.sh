#!/bin/sh

##
# Helper Functions
##

add_mod()
{
	# Make sure file and dir exists
	mkdir -p "$( echo "$1" | sed "s|/$( basename "$1" )\$||g" )"
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
	sed -i "/^#! *\\/bin/r $1.modtemp" "$1"
	rm "$1.modtemp"
}

make_exe()
{
	# Make sure dir exists and write file
	mkdir -p "$( echo "$1" | sed "s|/$( basename "$1" )\$||g" )"
	echo "$2" > "$1"

	# Make file executable
	chmod +x "$1"
}

install_init_script()
{
	local TARGET="/etc/init.d/$1"

	if [ -f "$TARGET" ]; then
		rm "$TARGET"
	fi

	cp "$MNT_USB/EnterRouterMode/bin/scripts/init.d-$1.sh" "$TARGET"

	# Fix file permissions
	chmod 755 "$TARGET"
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
	"$MNT_USB/EnterRouterMode/bin/scripts/device-setup.sh" \
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
install_init_script "fb_swap"
add_mod "/etc/init.d/fb_swap" "$(
	cat <<- EOF
		\$MNT_USB="$MNT_USB"
		\$SWAP_FILE="$MNT_USB/EnterRouterMode/var/swapfile"
		\$SWAP_LOCK="$MNT_USB/EnterRouterMode/var/swapfile.lock"
		\$SWAP_LOG="$MNT_USB/EnterRouterMode/log/swapfile.log"
	EOF
)"

# Stop swap and backup if disks go away
echo "Adding configs for when SD or USB drive is removed"
add_mod "/etc/udev/script/remove_usb_storage.sh" "$(
	cat <<- EOF
		# Kill the rsync process if the USB drive or SD card is removed
		if [ -f "$PIDFILE" ]; then
			kill "\$( cat "$PIDFILE" )"
			killall rsync
			rm -f "$PIDFILE"
		fi

		# Turn off swap on external drive, eat errors
		if [ -f "/etc/init.d/fb_swap" ]; then
			/etc/init.d/fb_swap stop || true
		fi
	EOF
)"

# Firewall configs
echo "Adding firewall configs to startup script"
install_init_script "fb_firewall"

add_mod "/etc/rc.local" "$(
	cat <<- EOF
		# Turn on firewall, eat errors
		if [ -f "/etc/init.d/fb_firewall" ]; then
			/etc/init.d/fb_firewall start || true

			# Maybe kill IPv6 based on \$ALLOW_IPV6 setting
			if [ "YES" != "$ALLOW_IPV6" ]; then
				/etc/init.d/fb_firewall block_ipv6 || true
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

# This is a flag used by the parent script sourcing this script so ignore not used warning
# shellcheck disable=SC2034
RESTART="TRUE"
exit 0
