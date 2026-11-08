#!/usr/bin/env bash

sudo fdisk -l /dev/loop0

lsblk -f /dev/loop0
