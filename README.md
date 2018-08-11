# Field Backup with RAVPower FileHub Plus

A set of scripts that will automatically backup SD cards inserted into the RAVPower FileHub Plus (RP-WD03) onto the attached USB drive. Backups are done incrementally with `rsync` and multiple cards may be backed up to the same USB backup drive in the field.

[![Build Status](https://travis-ci.org/xyu/FieldBackup.svg?branch=master)](https://travis-ci.org/xyu/FieldBackup)

## Installation

1. Copy the following files and dirs to the root of your USB backup drive:
```
EnterRouterMode
EnterRouterMode.sh
```
2. Turn on your router then plug in the USB backup drive and wait for the lights to stop flashing.

## Backing up SD cards to USB drive

You can backup multiple different SD cards to the same backup drive. Backups will be stored on the USB drive under `/SDMirrors/{SD_NAME}` where `SD_NAME` is a unique backup identifier for the card.

The first time a new SD card that has never been backed up is inserted a config file, `FieldBackup.conf`, will be written to the card and `SD_NAME` will be set to a random id. You can also customize the `SD_NAME` to whatever you like to make the directory names on the backup drive nicer.

Once the config file for how the SD card should be backed up has been written it's ok to lock the card for all subsequent backups.

## Mirroring data from USB Drive to SD card

It's also possible to make multiple copies of a SD card in the field via the USB backup drive, to do this edit `FieldBackup.conf` on the cards to be mirrored to each other so that they all have the same `SD_NAME`. Then set `SD_REPLICA` to `YES` on the cards that you want to have data copy from the USB drive to the SD card. You should have only one card with `SD_REPLICA=NO` which is your "master" card and it's the only card where data will copy from the card to the USB drive. All the "replica" cards will copy data from the USB drive to the card.

## Props

A lot of this is based on the work of the following people and repos:

* https://github.com/digidem/filehub-config
* https://github.com/steve8x8/filehub-config
* https://github.com/fbartels/filehub-config
* https://github.com/derfrankie/RAVPower-FileHub-SD-Backup
