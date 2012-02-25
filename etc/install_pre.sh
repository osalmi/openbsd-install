#!/bin/ksh

echo "Attempting to preserve files from previous install:"

if mkdir -p /mntold && mount -r /dev/${ROOTDISK}a /mntold; then
    (
        mkdir -p /tmp/preserve
        cd /mntold
        tar cvf - \
        etc/puppet/ssl \
        etc/puppet/puppet.conf \
        etc/ssh/ssh_host_key \
        etc/ssh/ssh_host_key.pub \
        etc/ssh/ssh_host_rsa_key \
        etc/ssh/ssh_host_rsa_key.pub \
        etc/ssh/ssh_host_dsa_key \
        etc/ssh/ssh_host_dsa_key.pub \
        | tar xpf - -C /tmp/preserve
    )

    # get old root password hash
    ROOTPASS=`sed -n 's/^root:\([^:]*\):.*/\1/p' /mntold/etc/master.passwd`

    umount /mntold
fi
