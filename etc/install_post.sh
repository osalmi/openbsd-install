#!/bin/ksh

if [ -d /tmp/preserve ]; then
    echo "Restoring preserved files."
    ( cd /tmp/preserve && tar cf - . | tar xpvf - -C /mnt )
fi
