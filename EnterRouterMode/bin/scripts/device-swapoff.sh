#!/bin/sh

if /etc/init.d/swap_to_usb_storage stop; then
	echo "Stopped swapping to USB storage"
else
	echo "Could not stop swapping to USB storage"
fi
