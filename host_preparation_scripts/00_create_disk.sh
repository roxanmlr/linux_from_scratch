#!/usr/bin/env bash

if [ ! -e disk.raw ]; then
	truncate -s 20G disk.raw	
fi
ls disk.raw -lh
echo "Disk space usage: $(du -h disk.raw)"
