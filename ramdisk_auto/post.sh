if [ -f /tmp/preserve.tar ]; then
    echo "Restoring preserved files."
    tar xpvf /tmp/preserve.tar -C /mnt
fi

if [ "${SITE_PATH}" ]; then
    echo "Installing site customizations."
    if [ -d "${SITE_PATH}" ]; then
        cd ${SITE_PATH} && tar cf - . | tar xvf - -C /mnt
    else
        ftp -V -o - ${SITE_PATH} | tar xzpvf - -C /mnt
    fi
fi

if [ -x /mnt/install.site ]; then
    echo "Running install.site script."
    /mnt/usr/sbin/chroot /mnt /install.site
fi
