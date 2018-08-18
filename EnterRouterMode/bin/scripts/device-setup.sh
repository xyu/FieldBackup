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

get_admin_pass_hash()
{
	local IFS USERNAME PASSWORD

	# Find password hash of admin user
	IFS=":"
	while read -r USERNAME PASSWORD _ ; do
		if [ "admin" = "$USERNAME" ]; then
			echo "$PASSWORD"
			return 0
		fi
	done < "$1"

	# Did not find password hash
	return 1
}

update_etc_passwd()
{
	local IFS OUTPUT ADMIN_PASS U_NAME U_PASS U_ID U_GID U_NICENAME U_HOME U_SHELL

	OUTPUT=""
	ADMIN_PASS="$( get_admin_pass_hash "$1" )"

	# Process /etc/passwd file
	IFS=":"
	while read -r U_NAME U_PASS U_ID U_GID U_NICENAME U_HOME U_SHELL ; do
		if [ "root" = "$U_NAME" ]; then
			# Reset home dir because /root does not exist
			U_HOME="/"

			# Reset root password to that of 'admin'?
			if [ "YES" = "$ROOT_PASS_RESET" ]; then
				echo "root password reset to admin password on '$1'"
				U_PASS="$ADMIN_PASS"
			fi

			# Allow logins as root?
			if [ "YES" = "$ROOT_LOGIN" ]; then
				echo "root login enabled on '$1'"
				U_SHELL="/bin/sh"
			else
				echo "root login disabled on '$1'"
				U_SHELL="/sbin/nologin"
			fi
		fi

		OUTPUT=$(
			printf '%s\n%s' \
				"$OUTPUT" \
				"$U_NAME:$U_PASS:$U_ID:$U_GID:$U_NICENAME:$U_HOME:$U_SHELL"
		)
	done < "$1"

	printf "$OUTPUT" | grep ":" > "$1"
}

update_etc_shadow()
{
	local IFS OUTPUT ADMIN_PASS U_NAME U_PASS U_DATA

	OUTPUT=""
	ADMIN_PASS="$( get_admin_pass_hash "$1" )"

	# Process file
	IFS=":"
	while read -r U_NAME U_PASS U_DATA ; do
		if [ "root" = "$U_NAME" ]; then
			# Reset root password to that of 'admin'?
			if [ "YES" = "$ROOT_PASS_RESET" ]; then
				echo "root password reset to admin password on '$1'"
				U_PASS="$ADMIN_PASS"
			fi
		fi

		OUTPUT=$(
			printf '%s\n%s' \
				"$OUTPUT" \
				"$U_NAME:$U_PASS:$U_DATA"
		)
	done < "$1"

	printf "$OUTPUT" | grep ":" > "$1"
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

# Update password files
update_etc_passwd "/etc/passwd"
update_etc_shadow "/etc/shadow"

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
		MNT_USB="$MNT_USB"
		SWAP_FILE="$MNT_USB/EnterRouterMode/var/swapfile"
		SWAP_LOCK="$MNT_USB/EnterRouterMode/var/swapfile.lock"
		SWAP_LOG="$MNT_USB/EnterRouterMode/log/swapfile.log"
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
		if [ -f "/etc/init.d/fb_firewall" ]; then
			/etc/init.d/fb_firewall restart || true

			# Maybe kill IPv6 based on \$ALLOW_IPV6 setting
			if [ "YES" != "$ALLOW_IPV6" ]; then
				/etc/init.d/fb_firewall block_ipv6 || true
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
