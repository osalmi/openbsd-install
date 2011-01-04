.PATH: ${.CURDIR}/../ramdisk
RAMDISK=RAMDISK_AUTO
FLOPPYSIZE=5760
FLOPPYTYPE=floppy288
XNAME=auto
NOFS=1
DISKTYPE=rdroot-8192
NBLKS=8192

.include "${.CURDIR}/../common/Makefile.inc"

LISTS+=		${.CURDIR}/../ramdisk_cd/list.local
LISTS+=		${.CURDIR}/list.local

.BEGIN:
	grep "^rdroot-8192" /etc/disktab || cat disktab >> /etc/disktab ; \
	sed -e 's/MINIROOTSIZE=.*/MINIROOTSIZE=8192/' \
	${.CURDIR}/../../../sys/arch/${MACHINE_ARCH}/conf/RAMDISK_CD > \
	${.CURDIR}/../../../sys/arch/${MACHINE_ARCH}/conf/RAMDISK_AUTO ; \
	sed -e '/^set_term$$/,$$s/^/#/' \
	${.CURDIR}/../../miniroot/install.sub > install.sub
