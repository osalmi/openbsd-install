.PATH: ${.CURDIR}/../ramdisk
RAMDISK=RAMDISK_AI
DISKTYPE=rdroot8
NBLKS=17920
XNAME=ai
NOFS=1

.include "${.CURDIR}/../common/Makefile.inc"

LISTS+=		${.CURDIR}/../ramdisk_cd/list.local
LISTS+=		${.CURDIR}/list.local

.BEGIN:
	grep "^rdroot8" /etc/disktab || cat disktab >> /etc/disktab ; \
	sed -e "s/MINIROOTSIZE=.*/MINIROOTSIZE=17920/' \
	${.CURDIR}/../../../sys/arch/${MACHINE_ARCH}/conf/RAMDISK_CD > \
	${.CURDIR}/../../../sys/arch/${MACHINE_ARCH}/conf/RAMDISK_AI ; \
	sed -e '/^set_term$$/,$$s/^/#/' \
	${.CURDIR}/../../miniroot/install.sub > install.sub
