# Building Custom Packages

The RAVPower FileHub Plus runs on a 32bit MIPS (little endian) chipset so we need to cross compile from source targeting that arch. The easiest way to do that is to use [Buildroot](https://buildroot.org).

## About Arch (Firmware v2.000.066)

With the latest firmware installed we get the following when inspecting the system.

```
# cat /proc/version
Linux version 2.6.36+ (zhangguoquan@localhost.localdomain) (gcc version 3.4.2) #411 Mon Jan 22 14:12:40 CST 2018
```

```
# cat /proc/cpuinfo
system type             : Ralink SoC
processor               : 0
cpu model               : MIPS 24Kc V5.0
BogoMIPS                : 386.04
wait instruction        : yes
microsecond timers      : yes
tlb_entries             : 32
extra interrupt vector  : yes
hardware watchpoint     : yes, count: 4, address/irw mask: [0x0000, 0x0ad0, 0x0ffb, 0x01a8]
ASEs implemented        : mips16 dsp
shadow register sets    : 1
core                    : 0
VCED exceptions         : not available
VCEI exceptions         : not available
```

```
# cat /proc/meminfo
MemTotal:          27160 kB
MemFree:            8136 kB
Buffers:            1424 kB
Cached:             6124 kB
SwapCached:            0 kB
Active:             4580 kB
Inactive:           5364 kB
Active(anon):       2396 kB
Inactive(anon):        0 kB
Active(file):       2184 kB
Inactive(file):     5364 kB
Unevictable:           0 kB
Mlocked:               0 kB
SwapTotal:             0 kB
SwapFree:              0 kB
Dirty:                 0 kB
Writeback:             0 kB
AnonPages:          2428 kB
Mapped:             2172 kB
Shmem:                 0 kB
Slab:               5800 kB
SReclaimable:        816 kB
SUnreclaim:         4984 kB
KernelStack:         464 kB
PageTables:          296 kB
NFS_Unstable:          0 kB
Bounce:                0 kB
WritebackTmp:          0 kB
CommitLimit:       13580 kB
Committed_AS:       6168 kB
VmallocTotal:    1048372 kB
VmallocUsed:        2776 kB
VmallocChunk:    1042460 kB
```

Inspecting files we get:

```
$ file busybox
busybox: ELF 32-bit LSB executable, MIPS, MIPS-II version 1 (SYSV), dynamically linked, interpreter /lib/ld-uClibc.so.0, stripped
```

Busybox is also quite old.

```
# /bin/busybox
BusyBox v1.12.1 (2013-09-18 20:10:25 CST) multi-call binary
Copyright (C) 1998-2008 Erik Andersen, Rob Landley, Denys Vlasenko
and others. Licensed under GPLv2.
See source distribution for full notice.

Usage: busybox [function] [arguments]...
   or: function [arguments]...

        BusyBox is a multi-call binary that combines many common Unix
        utilities into a single executable.  Most people will create a
        link to busybox for each function they wish to use and BusyBox
        will act like whatever it was invoked as!

Currently defined functions:
        ash, awk, basename, brctl, cat, chgrp, chmod, chown, chroot, cksum,
        clear, cmp, cp, cut, date, dd, depmod, df, dhcprelay, diff, dmesg,
        du, dumpleases, echo, egrep, env, expr, fgrep, find, free, getty,
        grep, gunzip, gzip, halt, hdparm, head, hostname, hwclock, ifconfig,
        insmod, ip, ipaddr, iplink, iproute, iprule, iptunnel, kill, killall,
        killall5, klogd, ln, logger, login, logread, ls, lsmod, md5sum,
        mkdir, mknod, mkswap, modprobe, mount, mv, netstat, nice, passwd,
        pidof, ping, poweroff, ps, pwd, readlink, realpath, reboot, reset,
        rm, rmdir, rmmod, route, sed, sh, sha1sum, sleep, stat, stty, sum,
        swapoff, swapon, sync, sysctl, syslogd, tail, tar, telnetd, time,
        top, touch, udhcpc, udhcpd, umount, uname, usleep, vconfig, vi,
        watchdog, wc, which, xargs, zcat
```

## Recompiling Packages

Included is a Vagrant file from Buildroot:

https://buildroot.org/downloads/Vagrantfile

Once that boots up with `vagrant up` ssh into it with `vagrant ssh`.

After that use `menuconfig` to configure the build image or use the included `buildroot.config`.

```
vagrant@vagrant:~$ cd buildroot-2018.05
vagrant@vagrant:~/buildroot-2018.05$ make menuconfig
```

To build the image use `make` the image will be output to `~/buildroot-2018.05/output/image/rootfs.tar`.
