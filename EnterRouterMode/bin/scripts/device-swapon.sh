#!/bin/sh

if /etc/init.d/swap_to_usb_storage start; then
	echo "Started swapping to USB storage"
else
	echo "Cannot swap to USB storage"
fi
