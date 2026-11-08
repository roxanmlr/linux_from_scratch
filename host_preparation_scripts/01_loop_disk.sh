#!/usr/bin/env bash
set -euo pipefail

if LOOP=$(losetup -j disk.raw | cut -d: -f1 | head -n1) && [ -n "$LOOP" ] ; then
	echo "already attached: $LOOP"
else
	LOOP=$(sudo losetup -fP --show disk.raw)
	echo "attached: $LOOP"
fi

echo "$LOOP" > .loopdev
