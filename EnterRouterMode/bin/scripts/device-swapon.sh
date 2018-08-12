#!/bin/sh

if /etc/init.d/fb_swap start; then
	echo "Started swapping to USB storage"
else
	echo "Cannot swap to USB storage"
fi
