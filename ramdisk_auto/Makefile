.PATH: ${.CURDIR}/../ramdisk
RAMDISK=RAMDISK_CD
FLOPPYSIZE=5760
FLOPPYTYPE=floppy288
XNAME=auto
NOFS=1

.include "${.CURDIR}/../common/Makefile.inc"

LISTS+=		${.CURDIR}/../ramdisk_cd/list.local
LISTS+=		${.CURDIR}/list.local

.BEGIN:
	sed -e '/^set_term$$/,$$s/^/#/' \
	${.CURDIR}/../../miniroot/install.sub > install.sub
