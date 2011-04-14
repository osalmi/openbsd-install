#!/bin/ksh

# Copyright (c) 2005-2010 Ossi Salmi
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

# URL to installation configuration
#
CFG_PATH=http://code.zebes.net/openbsd-ai/raw/tip/conf/install.conf

die() {
    echo "Fatal error: $*"
    exit 1
}

# install.sub needs to know the MODE
MODE=install

# include common subroutines and initialization code
. install.sub

# Network config
IFDEVS="`get_ifdevs`"
[ "${IFDEVS}" ] || die "no network interfaces found"

hostname localhost
ifconfig lo0 inet 127.0.0.1

if [ `echo "${IFDEVS}" | grep -c ''` -gt 1 ]; then
    # multiple interfaces, find the first interface with cable plugged in
    for i in ${IFDEVS}; do
        if ifconfig ${i} | grep -q "status: active"; then
            IFDEV=${i}
            break
        fi
    done

    while [ -z "${IFDEV}" ]; do
        ask_which "interface" "do you wish to use" "$_IFDEVS"
        if isin ${resp} ${IFDEVS}; then
            IFDEV=${resp}
            break
        fi
    done
else
    # just one interface, use it
    IFDEV=${IFDEVS}
fi

dhcp_request ${IFDEV} || die "did not receive DHCP lease"
echo "dhcp NONE NONE NONE" >/tmp/hostname.${IFDEV}

# Mount installroot if installing over nfs
if echo ${CFG_PATH} | grep -q "^nfs:"; then
    _installroot="`echo ${CFG_PATH} | sed "s@nfs://\([^/]*\)\(.*\)@\1:\2@"`"
    mkdir /installroot
    mount -o ro,tcp ${_installroot} /installroot >/dev/null 2>&1 || \
        die "failed to mount ${_installroot}"
    export CFG_PATH=file:/installroot/install.conf
fi

# fetch install.conf
ftp -V -o /install.conf ${CFG_PATH} || die "failed to fetch ${CFG_PATH}"
grep -q '^#!/bin/ksh' install.conf || die "invalid install.conf"
. install.conf

# figure out target HD
DKDEVS="`get_dkdevs`"
for dk in wd0 sd0; do
    if isin ${dk} ${DKDEVS}; then
        ROOTDISK=${dk}
        break
    fi
done
if [ "${ROOTDISK}" ]; then
    ROOTDEV=${ROOTDISK}a
    SWAPDEV=${ROOTDISK}b
    echo "/dev/${ROOTDEV} / ffs rw,softdep 1 1" >/tmp/fstab
else
    die "cannot determine target HD"
fi

export ARCH DKDEVS IFDEV ROOTDISK ROOTDEV SWAPDEV

# Run pre-install script
if [ "${PRE_PATH}" ]; then
    ftp -V -o /install.pre ${PRE_PATH} || die "failed to fetch ${PRE_PATH}"
    grep -q '^#!/bin/ksh' install.pre || die "invalid install.pre"
    . install.pre
fi

if [ -z "${ROOTPASS}" ]; then
    while :; do
        askpassword root
        _rootpass="$_password"
        [[ -n "$_password" ]] && break
        echo "The root password must be set."
    done
fi

# determine swap size (2 x memory, max 25% of disk)
MEMSIZE=`dmesg | sed -n '/real mem/s/.*(\([0-9]*\)MB)/\1/p' | sed '$!d'`
DISKSIZE=`disklabel -p m ${ROOTDISK} 2>&1 | sed -n '/^  c:/s/[^0-9]*\([0-9]*\)\.[0-9]M.*/\1/p'`
SWAPSIZE=$(((${MEMSIZE} + 1) * 2))
SWAPSIZE_MAX=$((${DISKSIZE} / 4))
export DISKSIZE

if [ ${DISKSIZE} -lt 4096 ]; then
    SWAPSIZE=0
elif [ ${SWAPSIZE} -gt ${SWAPSIZE_MAX} ]; then
    SWAPSIZE=${SWAPSIZE_MAX}
fi

fdisk -e ${ROOTDISK} <<EOF >/dev/null
reinit
update
write
quit
EOF

if [ ${SWAPSIZE} -gt 0 ]; then
    echo "Formatting disk ${ROOTDISK} (${SWAPSIZE}MB swap)."
    disklabel -E ${ROOTDISK} <<EOF >/dev/null
z
a b

${SWAPSIZE}M

a a



w
q
EOF

else
    echo "Formatting disk ${ROOTDISK} (no swap)."
    disklabel -E ${ROOTDISK} <<EOF >/dev/null
z
a a



w
q
EOF

fi

newfs -q /dev/r${ROOTDEV}
mount /dev/${ROOTDEV} /mnt

echo "Installing..."
# install base files
for i in bsd bsd.mp bsd.rd; do
    echo "$i"
    ftp -V -o /mnt/$i ${INSTALL_PATH}/$i
done
for i in ${THESETS}; do
    echo "${i}${VERSION}.tgz"
    ftp -V -o - ${INSTALL_PATH}/$i${VERSION}.tgz | tar zxphf - -C /mnt
done
echo "done."

echo -n "Saving settings..."

# Save any leases obtained during install.
( cd /var/db
[ -f dhclient.leases ] && mv dhclient.leases /mnt/var/db/. )

# Move configuration files from /tmp to /mnt/etc.
( cd /tmp

if [ "${USE_NTPD}" = "yes" ]; then
    echo "ntpd_flags=" >>/mnt/etc/rc.conf.local
fi

if [ "${USE_IPV6}" = "yes" ]; then
    echo "rtsol" >>hostname.${IFDEV}
fi

if [ "${USE_X11}" = "yes" ]; then
    sed 's/^#\(machdep\.allowaperture\)/\1/' /mnt/etc/sysctl.conf >sysctl.conf
fi

echo ${KBD} >kbdtype

# get fqdn from dns
cp resolv.conf.shadow resolv.conf
cp resolv.conf.shadow /mnt/etc/resolv.conf
myip=`ifconfig ${IFDEV} inet | sed -n '/inet/s/.* \([0-9.]*\) .*/\1/p'`
mydns=`/mnt/usr/sbin/chroot /mnt /usr/sbin/host ${myip} | grep pointer`
HOSTNAME=`echo ${mydns} | sed 's/.* pointer \([^.]*\).*/\1/'`
DOMAIN=`echo ${mydns} | sed 's/.* pointer [^.]*\.\(.*\)\./\1/'`
HOSTNAME=${HOSTNAME:-localhost}
DOMAIN=${DOMAIN:-localdomain}

hostname ${HOSTNAME}.${DOMAIN}
hostname >myname

cat >hosts <<EOF
127.0.0.1	localhost
::1		localhost
127.0.0.1	${HOSTNAME}.${DOMAIN} ${HOSTNAME}
::1		${HOSTNAME}.${DOMAIN} ${HOSTNAME}
EOF

# Append dhclient.conf to installed dhclient.conf.
_f=dhclient.conf
[[ -f $_f ]] && { cat $_f >>/mnt/etc/$_f ; rm $_f ; }

# Possible files: fstab hostname.* hosts kbdtype mygate myname ttys
#		  boot.conf resolv.conf sysctl.conf resolv.conf.tail
# Save only non-empty (-s) regular (-f) files.
for _f in fstab host* kbdtype my* ttys *.conf *.tail; do
	[[ -f $_f && -s $_f ]] && mv $_f /mnt/etc/.
done )

# Set the timezone
ln -sf /usr/share/zoneinfo/${TZ} /mnt/etc/localtime

# Feed the random pool some junk before we read from it
dmesg >/dev/urandom

/mnt/bin/dd if=/mnt/dev/urandom of=/mnt/var/db/host.random \
	bs=1024 count=64 >/dev/null 2>&1
chmod 600 /mnt/var/db/host.random >/dev/null 2>&1

# Set root password
[ "${ROOTPASS}" ] || ROOTPASS=`/mnt/usr/bin/encrypt -b 8 -- "$_rootpass"`
echo "1,s@^root::@root:${ROOTPASS}:@
w
q" | /mnt/bin/ed /mnt/etc/master.passwd 2>/dev/null
/mnt/usr/sbin/pwd_mkdb -p -d /mnt/etc /etc/master.passwd

echo "done."

# Run post-install script
if [ "${POST_PATH}" ]; then
    ftp -V -o /install.post ${POST_PATH} || die "failed to fetch ${POST_PATH}"
    grep -q '^#!/bin/ksh' install.post || die "invalid install.post"
    . install.post
fi

# Fetch site.tgz
if [ "${SITE_PATH}" ]; then
    echo "Installing site customizations."
    if [ -d "${SITE_PATH}" ]; then
        ( cd ${SITE_PATH} && tar cf - . | tar xvf - -C /mnt )
    else
        ftp -V -o - ${SITE_PATH} | tar xzpvf - -C /mnt
    fi
fi

# Perform final steps common to both an install and an upgrade.
finish_up
touch /tmp/.install_ok
