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

## Packages Included With Repo

We use a statically linked `rsync` in this repo, stripped with gcc optimizations for speed rather then size because we're going to be loading this from an external disk rather then from device flash.

```
$ file rsync
rsync: ELF 32-bit LSB executable, MIPS, MIPS32 rel2 version 1 (SYSV), statically linked, stripped
```

```
# ./rsync --version
rsync  version 3.1.3  protocol version 31
Copyright (C) 1996-2018 by Andrew Tridgell, Wayne Davison, and others.
Web site: http://rsync.samba.org/
Capabilities:
    64-bit files, 64-bit inums, 32-bit timestamps, 64-bit long ints,
    no socketpairs, hardlinks, symlinks, IPv6, batchfiles, inplace,
    append, no ACLs, xattrs, no iconv, symtimes, prealloc

rsync comes with ABSOLUTELY NO WARRANTY.  This is free software, and you
are welcome to redistribute it under certain conditions.  See the GNU
General Public Licence for details.
```

We also include a more up to date version of busybox to have access to more functions.

```
$ file busybox
busybox: ELF 32-bit LSB executable, MIPS, MIPS32 rel2 version 1 (SYSV), dynamically linked, interpreter /lib/ld-uClibc.so.0, stripped
```

```
# ./busybox
BusyBox v1.28.4 (2018-08-02 21:28:10 UTC) multi-call binary.
BusyBox is copyrighted by many authors between 1998-2015.
Licensed under GPLv2. See source distribution for detailed
copyright notices.

Usage: busybox [function [arguments]...]
   or: busybox --list[-full]
   or: busybox --install [-s] [DIR]
   or: function [arguments]...

        BusyBox is a multi-call binary that combines many common Unix
        utilities into a single executable.  Most people will create a
        link to busybox for each function they wish to use and BusyBox
        will act like whatever it was invoked as.

Currently defined functions:
        [, [[, addgroup, adduser, ar, arch, arp, arping, ash, awk, basename,
        blkid, bunzip2, bzcat, cat, chattr, chgrp, chmod, chown, chroot, chrt,
        chvt, cksum, clear, cmp, cp, cpio, crond, crontab, cut, date, dc, dd,
        deallocvt, delgroup, deluser, devmem, df, diff, dirname, dmesg, dnsd,
        dnsdomainname, dos2unix, du, dumpkmap, echo, egrep, eject, env,
        ether-wake, expr, factor, fallocate, false, fbset, fdflush, fdformat,
        fdisk, fgrep, find, flock, fold, free, freeramdisk, fsck, fsfreeze,
        fstrim, fuser, getopt, getty, grep, gunzip, gzip, halt, hdparm, head,
        hexdump, hexedit, hostid, hostname, hwclock, i2cdetect, i2cdump,
        i2cget, i2cset, id, ifconfig, ifdown, ifup, inetd, init, insmod,
        install, ip, ipaddr, ipcrm, ipcs, iplink, ipneigh, iproute, iprule,
        iptunnel, kill, killall, killall5, klogd, last, less, link, linux32,
        linux64, linuxrc, ln, loadfont, loadkmap, logger, login, logname,
        losetup, ls, lsattr, lsmod, lsof, lspci, lsscsi, lsusb, lzcat, lzma,
        lzopcat, makedevs, md5sum, mdev, mesg, microcom, mkdir, mkdosfs,
        mke2fs, mkfifo, mknod, mkpasswd, mkswap, mktemp, modprobe, more, mount,
        mountpoint, mt, mv, nameif, netstat, nice, nl, nohup, nproc, nslookup,
        nuke, od, openvt, partprobe, passwd, paste, patch, pidof, ping,
        pipe_progress, pivot_root, poweroff, printenv, printf, ps, pwd, rdate,
        readlink, readprofile, realpath, reboot, renice, reset, resize, resume,
        rm, rmdir, rmmod, route, run-init, run-parts, runlevel, sed, seq,
        setarch, setconsole, setfattr, setkeycodes, setlogcons, setpriv,
        setserial, setsid, sh, sha1sum, sha256sum, sha3sum, sha512sum, shred,
        sleep, sort, start-stop-daemon, strings, stty, su, sulogin, svc,
        swapoff, swapon, switch_root, sync, sysctl, syslogd, tail, tar, tee,
        telnet, test, tftp, time, top, touch, tr, traceroute, true, truncate,
        tty, ubirename, udhcpc, uevent, umount, uname, uniq, unix2dos, unlink,
        unlzma, unlzop, unxz, unzip, uptime, usleep, uudecode, uuencode,
        vconfig, vi, vlock, w, watch, watchdog, wc, wget, which, who, whoami,
        xargs, xxd, xz, xzcat, yes, zcat
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
