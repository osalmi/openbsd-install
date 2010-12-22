echo "Attempting to preserve files from previous install."

if mkdir /mntold && mount -r /dev/${ROOTDEV} /mntold; then
    # preserve files
    (
        cd /mntold
        tar cvf /tmp/preserve.tar \
        etc/puppet/ssl \
        etc/ssh/ssh_host_key \
        etc/ssh/ssh_host_key.pub \
        etc/ssh/ssh_host_rsa_key \
        etc/ssh/ssh_host_rsa_key.pub \
        etc/ssh/ssh_host_dsa_key \
        etc/ssh/ssh_host_dsa_key.pub \
        var/db/dhcpd.leases
    )

    # get old root password hash
    ROOTHASH=`sed -n 's/^root:\([^:]*\):.*/\1/p' /mntold/etc/master.passwd`

    umount /mntold
fi

if [ -z "${ROOTHASH}" ]; then
    while :; do
        askpassword root
        _rootpass="$_password"
        [[ -n "$_password" ]] && break
        echo "The root password must be set."
    done
fi
