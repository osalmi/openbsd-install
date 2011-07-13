#!/bin/ksh

if [ -s /tmp/preserve.tar.gz ]; then
    echo "Restoring preserved files."
    tar xzpvf /tmp/preserve.tar.gz -C /mnt
fi
