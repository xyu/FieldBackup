#!/bin/sh

##
# Field Backup with RAVPower FileHub Plus
# https://github.com/xyu/FieldBackup
##

start()
{
	#
	# Check that we are starting with empty chains
	#

	if [ "$( /bin/iptables -S | wc -l )" -gt 3 ]; then
		echo "Chains for 'filter' table not empty. Use $0 restart to flush and add chains"
		return 1
	fi

	#
	# Load interface names
	#

	# Use a mock for shellcheck
	# shellcheck source=dev/test/sbin/global.sh
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
	local IPDEV=""
	local IPADDR=""

	/bin/ip -6 -o addr show | while read -r _ IPDEV _ IPADDR _ ; do
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
