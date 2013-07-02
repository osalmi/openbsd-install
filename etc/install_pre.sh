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
		etc/ssh/ssh_host_dsa_key \
		etc/ssh/ssh_host_dsa_key.pub \
		etc/ssh/ssh_host_ecdsa_key \
		etc/ssh/ssh_host_ecdsa_key.pub \
		etc/ssh/ssh_host_rsa_key \
		etc/ssh/ssh_host_rsa_key.pub \
	| tar xpf - -C /tmp/preserve
	)

	# get old root password hash
	ROOTPASS=`sed -n 's/^root:\([^:]*\):.*/\1/p' /mntold/etc/master.passwd`

	# preserve extra local mounts
	egrep '^(/dev/[sw]d[0-9]+[a-z]|[0-9a-f]+\.[a-z])[[:space:]]+/[^[:space:]]+[[:space:]]+ffs' \
		/mntold/etc/fstab > /tmp/fstab.preserve

	umount /mntold && rmdir /mntold
fi
