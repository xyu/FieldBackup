#!/bin/sh

if /etc/init.d/fb_swap stop; then
	echo "Stopped swapping to USB storage"
else
	echo "Could not stop swapping to USB storage"
fi
