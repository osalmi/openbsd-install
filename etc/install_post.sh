#!/bin/ksh

if [ -d /tmp/preserve ]; then
    echo "Restoring preserved files:"
    ( cd /tmp/preserve && tar cf - . | tar xpvf - -C /mnt )
fi

if [ -s /tmp/fstab.preserve ]; then
    echo "Restoring preserved mounts:"
    cat /tmp/fstab.preserve
    cat /tmp/fstab.preserve >> /mnt/etc/fstab
    while read dev dir _; do mkdir -p /mnt${dir}; done < /tmp/fstab.preserve
fi
