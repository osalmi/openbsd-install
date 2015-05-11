PROG=		mount_tmpfs
SRCS=		mount_tmpfs.c getmntopts.c
MAN=		mount_tmpfs.8

MOUNT=		${.CURDIR}/../../../sbin/mount
.PATH:		${MOUNT}

CPPFLAGS+=	-I${MOUNT}
DPADD+=		${LIBUTIL}
LDADD+=		-lutil

.PATH:		${.CURDIR}/../../../sbin/mount_tmpfs
.include <bsd.prog.mk>
