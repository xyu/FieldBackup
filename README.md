# Field Backup with RAVPower FileHub Plus

A set of scripts that will automatically backup SD cards inserted into the RAVPower FileHub Plus (RP-WD03) onto the attached USB drive. Backups are done incrementally with `rsync` and multiple cards may be backed up to the same USB backup drive in the field.

[![Build Status](https://travis-ci.org/xyu/FieldBackup.svg?branch=master)](https://travis-ci.org/xyu/FieldBackup)

## Installation

1. Update the configs file to customize the installation (optional):
```
EnterRouterMode/conf
```
2. Copy the following files and directories to the root of your USB backup drive:
```
EnterRouterMode
EnterRouterMode.sh
```
3. Turn on the RAVPower FileHub Plus then plug the USB backup drive in and wait for the lights to stop flashing.

## Backing up SD cards to USB drive

You can backup multiple different SD cards to the same backup drive. Backups will be stored on the USB drive under `/SDMirrors/{SD_NAME}` where `SD_NAME` is a unique backup identifier for the card.

The first time a new SD card that has never been backed up is inserted a config file, `FieldBackup.conf`, will be written to the card and `SD_NAME` will be set to a random id. You can also customize the `SD_NAME` to whatever you like to make the directory names on the backup drive nicer.

Once the config file for how the SD card should be backed up has been written it's ok to lock the card for all subsequent backups.

## Mirroring data from USB Drive to SD card

It's also possible to make multiple copies of a SD card in the field via the USB backup drive, to do this edit `FieldBackup.conf` on the cards to be mirrored to each other so that they all have the same `SD_NAME`. Then set `SD_REPLICA` to `YES` on the cards that you want to have data copy from the USB drive to the SD card. You should have only one card with `SD_REPLICA=NO` which is your "master" card and it's the only card where data will copy from the card to the USB drive. All the "replica" cards will copy data from the USB drive to the card.

## Required Packages Included With Repo

We use a statically linked `rsync` in this repo, stripped with gcc optimizations for size. While space is not really an issue as we're going to be loading this from an external disk the device memory is small so we'll limit what needs to load.

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

## Optional Packages Included With Repo

These packages are not needed for the FieldBackup feature to work but are useful if you want to telnet into the device and do more advanced things. They are included as a convenience.

### BusyBox

A more up to date version of busybox which provides access to more functions, this is dynamically linked to system libs to reduce its memory footprint.

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

### SSH

The full suite of SSH tools to securely send and receive files, all statically linked to not depend on system libraries.

Note: If having an SSH daemon running on the device is useful to you it's probably better if you moved `sshd` to the device NVRAM.

```
$ file scp sftp ssh*
scp:         ELF 32-bit LSB executable, MIPS, MIPS32 rel2 version 1 (SYSV), statically linked, stripped
sftp:        ELF 32-bit LSB executable, MIPS, MIPS32 rel2 version 1 (SYSV), statically linked, stripped
ssh:         ELF 32-bit LSB executable, MIPS, MIPS32 rel2 version 1 (SYSV), statically linked, stripped
ssh-add:     ELF 32-bit LSB executable, MIPS, MIPS32 rel2 version 1 (SYSV), statically linked, stripped
ssh-agent:   ELF 32-bit LSB executable, MIPS, MIPS32 rel2 version 1 (SYSV), statically linked, stripped
ssh-keygen:  ELF 32-bit LSB executable, MIPS, MIPS32 rel2 version 1 (SYSV), statically linked, stripped
ssh-keyscan: ELF 32-bit LSB executable, MIPS, MIPS32 rel2 version 1 (SYSV), statically linked, stripped
sshd:        ELF 32-bit LSB executable, MIPS, MIPS32 rel2 version 1 (SYSV), statically linked, stripped
```

### OpenVPN

OpenVPN might be useful for setting up a VPN tunnel from the device itself.

```
$ file openvpn
openvpn: ELF 32-bit LSB executable, MIPS, MIPS32 rel2 version 1 (SYSV), statically linked, stripped
```

```
# ./openvpn --version
OpenVPN 2.4.6 mipsel-buildroot-linux-uclibc [SSL (OpenSSL)] [LZO] [LZ4] [EPOLL] [MH/PKTINFO] [AEAD] built on Aug 10 2018
library versions: OpenSSL 1.0.2o  27 Mar 2018, LZO 2.10
Originally developed by James Yonan
Copyright (C) 2002-2018 OpenVPN Inc <sales@openvpn.net>
Compile time defines: enable_async_push=no enable_comp_stub=no enable_crypto=yes enable_crypto_ofb_cfb=yes enable_debug=yes enable_def_auth=yes enable_dependency_tracking=no enable_dlopen=unknown enable_dlopen_self=unknown enable_dlopen_self_static=unknown enable_doc=no enable_docs=no enable_documentation=no enable_fast_install=needless enable_fragment=yes enable_gtk_doc=no enable_gtk_doc_html=noenable_iproute2=yes enable_ipv6=yes enable_libtool_lock=yes enable_lz4=yes enable_lzo=yes enable_management=yes enable_multihome=yes enable_nls=no enable_pam_dlopen=no enable_pedantic=no enable_pf=yes enable_pkcs11=no enable_plugin_auth_pam=no enable_plugin_down_root=no enable_plugins=no enable_port_share=yes enable_selinux=no enable_server=yes enable_shared=no enable_shared_with_static_runtimes=no enable_small=no enable_static=yes enable_strict=no enable_strict_options=no enable_systemd=no enable_werror=no enable_win32_dll=yes enable_x509_alt_username=no with_aix_soname=aix with_crypto_library=openssl with_fop=no with_gnu_ld=yes with_mem_check=no with_sysroot=no with_xmlto=no
```

## Props

A lot of this is based on the work of the following people and repos:

* https://github.com/digidem/filehub-config
* https://github.com/steve8x8/filehub-config
* https://github.com/fbartels/filehub-config
* https://github.com/derfrankie/RAVPower-FileHub-SD-Backup
