#!/bin/ksh

# Copyright (c) 2005-2011 Ossi Salmi
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
CFG_PATH=http://code.zebes.net/openbsd-ai/raw/tip/etc/install.conf
#CFG_PATH=nfs://install/export/install/OpenBSD/${VNAME}

die() {
    echo "Fatal error: $*"
    exit 1
}

# install.sub needs to know the MODE
MODE=install

# include common subroutines and initialization code
. install.sub

_ifdevs=$(get_ifdevs)
set -- $_ifdevs
if [ $# -eq 0 ]; then
    die "no network interfaces found"
elif [ $# -eq 1 ]; then
    IFDEV=$1
else
    # try to find first active interface
    while ifconfig $1 | grep -q -v "status: active"; do shift; done
    IFDEV=$1

    while [ -z "$IFDEV" ]; do
        ask_which "interface" "do you wish to use" "$_ifdevs"
        if isin $resp $_ifdevs; then
            IFDEV=$resp
            break
        fi
    done
fi

ifconfig lo0 inet 127.0.0.1/8
hostname localhost.localdomain
dhcp_request $IFDEV || die "did not receive DHCP lease"
echo "dhcp" >/tmp/hostname.$IFDEV

# mount install root if installing over nfs
if echo $CFG_PATH | grep -q "^nfs:"; then
    _install="`echo $CFG_PATH | sed "s@nfs://\([^/]*\)\(.*\)@\1:\2@"`"
    mount -o ro,tcp $_install /mnt2 >/dev/null 2>&1 || \
        die "failed to mount $_install"
    CFG_PATH=file:/mnt2/install.conf
fi

ftp -V -o /install.conf $CFG_PATH || die "failed to fetch $CFG_PATH"
grep -q '^#!/bin/ksh' install.conf || die "invalid install.conf"
. install.conf

# figure out target HD
DKDEVS=$(get_dkdevs)
for dk in wd0 sd0; do
    if isin $dk $DKDEVS; then
        ROOTDISK=$dk
        break
    fi
done
[ -n "$ROOTDISK" ] || die "cannot determine target HD"

export ARCH IFDEV DKDEVS ROOTDISK

if [ "$PRE_PATH" ]; then
    ftp -V -o /install.pre $PRE_PATH || die "failed to fetch $PRE_PATH"
    grep -q '^#!/bin/ksh' install.pre || die "invalid install.pre"
    . install.pre
fi

if [ -z "$ROOTPASS" ]; then
    while :; do
        askpassword root
        _rootpass="$_password"
        [[ -n "$_password" ]] && break
        echo "The root password must be set."
    done
fi

# determine swap size (2 x memory, max 25% of disk)
MEMSIZE=$(scan_dmesg '/real mem/s/.*(\([0-9]*\)MB)/\1/p')
DISKSIZE=$(disklabel -p m $ROOTDISK 2>&1 | sed -n '/^  c:/s/[^0-9]*\([0-9]*\)\.[0-9]M.*/\1/p')
SWAPSIZE=$(( ($MEMSIZE + 1) * 2 ))
SWAPSIZE_MAX=$(( $DISKSIZE / 4 ))
export DISKSIZE

if [ $DISKSIZE -lt 4096 ]; then
    SWAPSIZE=0
elif [ $SWAPSIZE -gt $SWAPSIZE_MAX ]; then
    SWAPSIZE=$SWAPSIZE_MAX
fi

fdisk -e $ROOTDISK <<EOF >/dev/null
reinit
update
write
quit
EOF

echo "z" > /tmp/disklabel.$ROOTDISK
[ $SWAPSIZE -gt 0 ] && cat >> /tmp/disklabel.$ROOTDISK <<EOF
a b

${SWAPSIZE}M

EOF
cat >> /tmp/disklabel.$ROOTDISK <<EOF
a a



/
w
q
EOF

echo "Labeling disk $ROOTDISK ($SWAPSIZE MB swap)."
disklabel -F /tmp/fstab -E $ROOTDISK < /tmp/disklabel.$ROOTDISK > /dev/null
while read _pp _mp _fstype _rest; do
    [[ $_fstype == ffs ]] || continue
    newfs -q ${_pp##/dev/}
done < /tmp/fstab
munge_fstab
mount_fs "-o async"

echo "Installing the sets:"
for i in bsd bsd.mp bsd.rd; do
    echo "* $i"
    ftp -V -o /mnt/$i ${INSTALL_PATH}/$i
done
for i in $THESETS; do
    echo "* ${i}${VERSION}.tgz"
    ftp -V -o - ${INSTALL_PATH}/$i${VERSION}.tgz | tar zxphf - -C /mnt
done

echo "Saving configuration files."

# Save any leases obtained during install.
( cd /var/db
[ -f dhclient.leases ] && mv dhclient.leases /mnt/var/db/. )

# Move configuration files from /tmp to /mnt/etc.
( cd /tmp

[ "$USE_IPV6" = "yes" ] && echo "rtsol" >>hostname.$IFDEV
[ "$USE_NTPD" = "yes" ] && echo "ntpd_flags=" >>/mnt/etc/rc.conf.local
[ "$USE_X11" = "yes" ] && \
    sed 's/^#\(machdep\.allowaperture\)/\1/' /mnt/etc/sysctl.conf >sysctl.conf

echo $KBD > kbdtype

# get fqdn from dns
cp resolv.conf.shadow resolv.conf
cp resolv.conf.shadow /mnt/etc/resolv.conf
_ip=$(ifconfig $IFDEV inet | sed -n '/inet/s/.* \([0-9.]*\) .*/\1/p')
_dns=$(/mnt/usr/sbin/chroot /mnt /usr/sbin/host $_ip | grep pointer)
HOSTNAME=$(echo $_dns | sed 's/.* pointer \([^.]*\).*/\1/')
DOMAIN=$(echo $_dns | sed 's/.* pointer [^.]*\.\(.*\)\./\1/')
HOSTNAME=${HOSTNAME:-localhost}
DOMAIN=${DOMAIN:-localdomain}

hostname ${HOSTNAME}.${DOMAIN}
hostname > myname

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
ln -sf /usr/share/zoneinfo/$TZ /mnt/etc/localtime

# Feed the random pool some junk before we read from it
(dmesg; sysctl; route -n show; df;
	ifconfig -A; hostname) >/mnt/dev/arandom 2>&1

echo "Generating initial host.random file."
/mnt/bin/dd if=/mnt/dev/arandom of=/mnt/var/db/host.random \
	bs=65536 count=1 >/dev/null 2>&1
chmod 600 /mnt/var/db/host.random >/dev/null 2>&1

echo "Setting root password."
[ "$ROOTPASS" ] || ROOTPASS=`/mnt/usr/bin/encrypt -b 8 -- "$_rootpass"`
echo "1,s@^root::@root:${ROOTPASS}:@
w
q" | /mnt/bin/ed /mnt/etc/master.passwd 2>/dev/null
/mnt/usr/sbin/pwd_mkdb -p -d /mnt/etc /etc/master.passwd

if grep -qs '^rtsol' /mnt/etc/hostname.*; then
    sed -e "/^#\(net\.inet6\.ip6\.accept_rtadv\)/s//\1/" \
        /mnt/etc/sysctl.conf >/tmp/sysctl.conf
    cp /tmp/sysctl.conf /mnt/etc/sysctl.conf
fi

if [ "$POST_PATH" ]; then
    ftp -V -o /install.post $POST_PATH || die "failed to fetch $POST_PATH"
    grep -q '^#!/bin/ksh' install.post || die "invalid install.post"
    . install.post
fi

if [ "$SITE_PATH" ]; then
    echo "Installing site customizations:"
    if [ -d "$SITE_PATH" ]; then
        ( cd $SITE_PATH && tar cf - . | tar xvf - -C /mnt )
    else
        ftp -V -o - $SITE_PATH | tar xzpvf - -C /mnt
    fi
fi

# Perform final steps common to both an install and an upgrade.
finish_up

echo "Creating installation notes."
cat > /mnt/root/install-notes.log <<EOF
Installation date:	`date`
Installation time:	${SECONDS} seconds
Determined ip:		${_ip}
Determined fqdn:	`hostname`
Determined disks:	${DKDEVS}
Determined root disk:	${ROOTDISK}
Determined interface:	${IFDEV}
EOF

echo -n > /tmp/.install_finished
